#!/usr/bin/perl
# SPDX-License-Identifier: Apache-2.0
# Vigia das entradas do FTP: conta as senhas erradas e cria o bloqueio que o porteiro aplica.
#
# O Pure-FTPd só avisa da senha errada pelo syslog. O vigia escuta em /dev/log, lê cada aviso e, quando um
# endereço erra a senha de um usuário vezes demais, grava /auth/bloqueios/<usuario>@<endereco>. Quem recusa
# a entrada é o porteiro (allsafe-ftp-porteiro), que só olha se esse arquivo existe e ainda vale: apagar o
# arquivo desbloqueia na hora. A senha nunca chega aqui: o aviso traz só o nome e o endereço.
#
# É também por aqui que as transferências chegam ao registro do container: o Pure-FTPd avisa pelo syslog de
# cada arquivo enviado, baixado, renomeado e apagado, e o vigia escreve uma linha para cada um.
#
#   limiar e minutos: os do usuário, em /auth/limites.lista (tentativas=N minutos=N), ou os da stack
#                     (FTP_BLOQUEIO_TENTATIVAS e FTP_BLOQUEIO_MINUTOS); limiar 0 = não bloqueia;
#   não contam:       os endereços da rede interna da stack (o painel confere a senha do usuário no FTP e
#                     tem o limite de tentativas dele), a recusa do porteiro por falta de TLS, a tentativa
#                     feita durante o bloqueio e o nome que não está no cadastro;
#   entrada certa:    zera a contagem daquele endereço para aquele usuário.
#
# Só módulos do perl-base, que já vem na imagem. O laço não espera por nada além do soquete: se ele parar
# de ler, o Pure-FTPd trava ao registrar. Se o vigia sair, o entrypoint encerra o container.
use strict;
use warnings;
use Fcntl qw(:DEFAULT :flock);
use Socket qw(AF_UNIX SOCK_DGRAM pack_sockaddr_un);
use Time::HiRes ();

my $SOQUETE   = '/dev/log';
my $BLOQUEIOS = '/auth/bloqueios';
my $RECUSAS   = '/run/allsafe/recusa';
my $CADASTRO  = '/auth/pureftpd.passwd';
my $LIMITES   = '/auth/limites.lista';
my $REDE      = '/auth/rede.estado';
my $RECURSOS  = '/auth/recursos.estado';
my $CGROUP    = '/sys/fs/cgroup';
my $TRAVA     = '/auth/.lock';
my $DADOS     = '/data';
my $PASTA     = qr{[A-Za-z0-9_][A-Za-z0-9._-]{0,63}(?:/[A-Za-z0-9_][A-Za-z0-9._-]{0,63}){0,3}};
# Identidades de sistema dos perfis, as mesmas do allsafe-ftp-user: o perfil é o uid gravado no cadastro.
my ($UID_DADOS, $GID_DADOS, $UID_ENVIO, $UID_LEITURA, $UID_SOENVIO) = (10000, 10000, 10002, 10003, 10004);
# Perfil só envio: a conta fica presa na área de entrada dela e o arquivo que chega é movido para a pasta do usuário.
my $ENTRADA   = "$DADOS/.entrada";
require '/usr/local/lib/allsafe/entrada.pl';
my $NOME      = qr/[a-z_][a-z0-9_-]{0,31}/;
my $ENDERECO  = qr/[0-9a-fA-F.:]{2,45}/;
my $CHAVES_MAX    = 10000;   # contagens guardadas na memória
my $BLOQUEIOS_MAX = 4096;    # arquivos de bloqueio
my $RECUSA_VALE   = 30;      # segundos em que a marca de recusa do porteiro ainda explica uma falha
my $REDE_CADA     = 5;       # segundos entre duas leituras dos contadores de rede e dos recursos do container
my $RECURSOS_VALE = 60;      # segundos: container parado publica os recursos uma vez nesse tempo

sub registrar { print STDERR "vigia: $_[0]\n"; }

sub inteiro {
    my ($texto, $minimo, $maximo, $padrao) = @_;
    return $padrao unless defined $texto && $texto =~ /^\d{1,6}$/ && $texto >= $minimo && $texto <= $maximo;
    return $texto + 0;
}
my $PADRAO_TENTATIVAS = inteiro($ENV{FTP_BLOQUEIO_TENTATIVAS}, 0, 100, 5);
my $PADRAO_MINUTOS    = inteiro($ENV{FTP_BLOQUEIO_MINUTOS}, 1, 1440, 15);

# Rede interna da stack: as redes ligadas direto ao container, fora o endereço de saída (o gateway), que é
# por onde chegam os clientes do próprio host. Lida uma vez de /proc/net/route, sem consulta de nomes.
my (@redes, $saida);
sub ler_redes {
    open(my $arq, '<', '/proc/net/route') or return;
    <$arq>;
    while (my $linha = <$arq>) {
        my @campo = split ' ', $linha;
        next unless @campo >= 8 && $campo[1] =~ /^[0-9A-Fa-f]{8}$/ && $campo[2] =~ /^[0-9A-Fa-f]{8}$/ && $campo[7] =~ /^[0-9A-Fa-f]{8}$/;
        my ($destino, $porta, $mascara) = map { unpack('N', pack('L', hex $_)) } @campo[1, 2, 7];
        if ($destino == 0 && $mascara == 0) { $saida = $porta if $porta; }
        elsif ($porta == 0 && $mascara != 0) { push @redes, [$destino, $mascara]; }
    }
    close $arq;
}
sub interno {
    my ($ip) = @_;
    return 0 unless $ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ && $1 < 256 && $2 < 256 && $3 < 256 && $4 < 256;
    return 1 if $1 == 127;
    my $numero = ($1 << 24) | ($2 << 16) | ($3 << 8) | $4;
    return 0 if defined $saida && $numero == $saida;
    for my $rede (@redes) { return 1 if ($numero & $rede->[1]) == $rede->[0]; }
    return 0;
}

# Cadastro e limites próprios, relidos só quando o arquivo muda (inode, tamanho e data).
my (%existe, %proprio, %perfil, %casa, %destino);
my ($visto_cadastro, $visto_limites) = ('?', '?');
sub marca { my @s = stat($_[0]); return @s ? "$s[1]:$s[7]:$s[9]" : ''; }
sub atualizar {
    my $agora = marca($CADASTRO);
    if ($agora ne $visto_cadastro) {
        %existe = %perfil = %casa = %destino = ();
        if (open(my $arq, '<', $CADASTRO)) {
            while (my $linha = <$arq>) {
                next unless $linha =~ /^($NOME):/;
                $existe{$1} = 1;
                my @campos = split /:/, $linha;
                next unless @campos > 5 && $campos[2] =~ /^\d{1,10}$/;
                # Só envio: a pasta da sessão é a área de entrada, e a pasta do usuário vai no campo da descrição.
                if ($campos[2] == $UID_SOENVIO) {
                    $destino{$campos[0]} = $campos[4] if $campos[4] =~ /^$PASTA$/ && $campos[5] eq "$ENTRADA/$campos[0]/./";
                    next;
                }
                next unless $campos[5] =~ m{^$DADOS/($PASTA)/\./$};
                $casa{$campos[0]} = $1;
                $perfil{$campos[0]} = $campos[2] == $UID_ENVIO ? 'envio' : $campos[2] == $UID_LEITURA ? 'leitura' : 'completo';
            }
            close $arq;
        }
        $visto_cadastro = $agora;
    }
    $agora = marca($LIMITES);
    if ($agora ne $visto_limites) {
        %proprio = ();
        if (open(my $arq, '<', $LIMITES)) {
            while (my $linha = <$arq>) {
                my ($nome, @pares) = split ' ', $linha;
                next unless defined $nome && $nome =~ /^$NOME$/;
                for my $par (@pares) {
                    $proprio{$nome}{tentativas} = $1 + 0 if $par =~ /^tentativas=(\d{1,6})$/ && $1 <= 100;
                    $proprio{$nome}{minutos}    = $1 + 0 if $par =~ /^minutos=(\d{1,6})$/ && $1 >= 1 && $1 <= 1440;
                }
            }
            close $arq;
        }
        $visto_limites = $agora;
    }
}

# Bloqueio: o arquivo é a única memória. Linha: <vale até> <desde> <senhas erradas>, em segundos desde 1970.
sub bloqueado {
    my ($nome, $ip) = @_;
    open(my $arq, '<', "$BLOQUEIOS/$nome\@$ip") or return 0;
    my $linha = <$arq> // '';
    close $arq;
    return $linha =~ /^(\d{1,12}) / && $1 > time ? 1 : 0;
}
sub bloquear {
    my ($nome, $ip, $erradas, $minutos) = @_;
    my $agora = time;
    opendir(my $pasta, $BLOQUEIOS) or return registrar("FALHA: $BLOQUEIOS não abre: bloqueio de usuario=$nome origem=$ip não gravado");
    my $quantos = grep { !/^\./ } readdir $pasta;
    closedir $pasta;
    return registrar("AVISO: $quantos bloqueios em vigor, o teto: bloqueio de usuario=$nome origem=$ip não gravado") if $quantos >= $BLOQUEIOS_MAX;
    my $novo = "$BLOQUEIOS/.novo.$$";
    open(my $arq, '>', $novo) or return registrar("FALHA: bloqueio de usuario=$nome origem=$ip não gravado");
    printf $arq "%d %d %d\n", $agora + $minutos * 60, $agora, $erradas;
    close $arq;
    rename($novo, "$BLOQUEIOS/$nome\@$ip") or return registrar("FALHA: bloqueio de usuario=$nome origem=$ip não gravado");
    registrar("entrada bloqueada: usuario=$nome origem=$ip senhas_erradas=$erradas minutos=$minutos");
}

# Marca que o porteiro deixa quando é ele quem recusa por falta de TLS: essa falha não é senha errada.
sub recusa_do_porteiro {
    my ($nome, $ip) = @_;
    opendir(my $pasta, $RECUSAS) or return 0;
    my @marcas = grep { /^\Q$ip\E\@\Q$nome\E\.\d+$/ } readdir $pasta;
    closedir $pasta;
    for my $marca (@marcas) {
        my @s = stat("$RECUSAS/$marca") or next;
        return 1 if time - $s[9] <= $RECUSA_VALE && unlink("$RECUSAS/$marca");
    }
    return 0;
}

my %falhas;   # "usuario@endereco" ➜ instantes das senhas erradas ainda dentro da janela
sub senha_errada {
    my ($ip, $nome) = @_;
    return registrar("entrada recusada: nome fora da regra, origem=$ip") unless $nome =~ /^$NOME$/;
    return if recusa_do_porteiro($nome, $ip);
    return registrar("entrada recusada: usuario=$nome origem=$ip (rede interna da stack: não conta para o bloqueio)") if interno($ip);
    return registrar("entrada recusada pelo bloqueio: usuario=$nome origem=$ip") if bloqueado($nome, $ip);
    atualizar();
    return registrar("entrada recusada: usuario=$nome origem=$ip (não está no cadastro)") unless $existe{$nome};
    my $limiar  = $proprio{$nome}{tentativas} // $PADRAO_TENTATIVAS;
    my $minutos = $proprio{$nome}{minutos} // $PADRAO_MINUTOS;
    return registrar("entrada recusada: usuario=$nome origem=$ip (bloqueio por tentativa desligado)") if $limiar == 0;
    my $agora = time;
    my $chave = "$nome\@$ip";
    if (!$falhas{$chave} && keys(%falhas) >= $CHAVES_MAX) {
        registrar("AVISO: $CHAVES_MAX contagens na memória, o teto: as contagens recomeçam");
        %falhas = ();
    }
    my @dentro = grep { $agora - $_ < $minutos * 60 } @{ $falhas{$chave} // [] };
    push @dentro, $agora;
    registrar("entrada recusada: usuario=$nome origem=$ip senhas_erradas=" . scalar(@dentro) . " de $limiar");
    if (@dentro >= $limiar) {
        delete $falhas{$chave};
        bloquear($nome, $ip, scalar(@dentro), $minutos);
    } else {
        $falhas{$chave} = \@dentro;
    }
}

sub entrada_certa {
    my ($ip, $nome) = @_;
    delete $falhas{"$nome\@$ip"};
    registrar("entrada: usuario=$nome origem=$ip");
    # A pasta que o servidor acabou de criar para a conta (sumiu e a conta entrou) nasce dela: volta ao ftpdata.
    atualizar();
    entregar($nome) if ($perfil{$nome} // 'completo') ne 'completo';
}

# Modo da pasta de um usuário, pelo perfil de quem a alcança (quem tem a mesma pasta ou uma acima): a mesma
# conta do allsafe-ftp-user. Com envio, o grupo grava e vale o bit de permanência; com leitura, "outros" entra.
sub modo_da_pasta {
    my ($pasta) = @_;
    my $modo = 0750;
    for my $nome (keys %casa) {
        next unless $pasta eq $casa{$nome} || index($pasta, "$casa{$nome}/") == 0;
        $modo |= 01020 if $perfil{$nome} eq 'envio';
        $modo |= 00005 if $perfil{$nome} eq 'leitura';
    }
    return $modo;
}

# Entrega: o que uma conta de envio acabou de gravar passa para o ftpdata, e as pastas do caminho ficam com o
# modo da pasta do usuário. Depois disso a conta de envio não troca, não renomeia e não apaga o arquivo: no
# FTP ela só é dona do que ainda não foi entregue. O caminho vem do aviso do servidor, com o nome que o cliente
# escolheu: é aberto nível por nível a partir do /data, sem seguir link simbólico, e o dono e o modo são
# trocados no que foi aberto, não no nome. Sem arquivo, só a pasta do usuário é conferida.
sub entregar {
    my ($conta, $caminho) = @_;
    my $pasta = $casa{$conta} // return;
    my $modo = modo_da_pasta($pasta);
    return if $modo == 0750;   # só perfil completo alcança a pasta: nada a entregar
    my (@niveis, $arquivo);
    if (defined $caminho) {
        $caminho =~ s{/{2,}}{/}g;
        return unless index($caminho, "$DADOS/$pasta/") == 0;
        @niveis = split m{/}, substr($caminho, length("$DADOS/$pasta/")), -1;
        $arquivo = pop @niveis;
        return if !defined $arquivo || grep { $_ eq '' || $_ eq '.' || $_ eq '..' } @niveis, $arquivo;
    }
    my @acima = split m{/}, $pasta;
    my $feito = eval {
        chdir($DADOS) or die "pasta de dados\n";
        my $nivel = 0;
        for my $nome (@acima, @niveis) {
            sysopen(my $aberta, $nome, O_RDONLY | O_NOFOLLOW | O_DIRECTORY) or die "pasta\n";
            chdir($aberta) or die "pasta\n";
            next if ++$nivel < @acima;   # acima da pasta do usuário nada muda
            my @estado = stat($aberta) or die "pasta\n";
            if ($estado[4] != $UID_DADOS || $estado[5] != $GID_DADOS) { chown($UID_DADOS, $GID_DADOS, $aberta) or die "dono da pasta\n"; }
            if (($estado[2] & 07777) != $modo) { chmod($modo, $aberta) or die "modo da pasta\n"; }
        }
        if (defined $arquivo) {
            sysopen(my $aberto, $arquivo, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or die "arquivo\n";
            my @estado = stat($aberto) or die "arquivo\n";
            if (-f _ && $estado[3] == 1 && $estado[4] == $UID_ENVIO) { chown($UID_DADOS, $GID_DADOS, $aberto) or die "dono do arquivo\n"; }
        }
        1;
    };
    my $motivo = $@;
    chdir('/');
    return if $feito;
    chomp $motivo;
    registrar("entrega nao feita ($motivo): usuario=$conta" . (defined $caminho ? ' arquivo=' . limpo($caminho, 400) : ''));
}

# Só envio: o arquivo que acabou de chegar à área de entrada da conta vai para a pasta do usuário. Devolve o
# caminho em que ele ficou, que é o que vai para o registro; sem a entrega, o da área, onde ele continua.
sub da_entrada {
    my ($conta, $caminho) = @_;
    $caminho =~ s{/{2,}}{/}g;
    my $area = "$ENTRADA/$conta/";
    my ($final, $motivo) = index($caminho, $area) == 0
        ? entrada_mover($conta, $destino{$conta}, substr($caminho, length $area)) : (undef, 'fora da área de entrada');
    return $final if defined $final;
    registrar("entrega nao feita ($motivo): usuario=$conta arquivo=" . limpo($caminho, 400));
    return $caminho;
}

# Nome de arquivo vem do cliente: antes de ir para o registro, perde o que quebraria a linha ou comandaria o
# terminal de quem lê (caractere de controle e de direção do texto). UTF-8 válido passa; o resto vira "?".
sub limpo {
    my ($texto, $teto) = @_;
    $texto =~ s{/{2,}}{/}g;
    if (utf8::decode($texto)) {
        $texto =~ s/[^\x20-\x7e\xa0-\x{200a}\x{2010}-\x{2027}\x{2030}-\x{205f}\x{2070}-\x{d7ff}\x{e000}-\x{fefe}\x{ff00}-\x{fffd}]/?/g;
        $texto = substr($texto, 0, $teto);
        utf8::encode($texto);
    } else {
        $texto =~ s/[^\x20-\x7e]/?/g;
        $texto = substr($texto, 0, $teto);
    }
    return $texto;
}

# Arquivo enviado, baixado, apagado e renomeado: o texto é o do Pure-FTPd, com o nome do arquivo no meio.
# O nome vai por último na linha, e o tamanho é lido do fim do texto: nome nenhum se passa por outro campo.
# O aviso é reconhecido pelo começo, que é do servidor: o de envio e o de download começam pelo caminho
# completo ("/data/..."), e um arquivo apagado cujo nome imita o fim de um envio continua sendo "apagado".
sub arquivo {
    my ($conta, $ip, $texto) = @_;
    return unless $conta =~ /^$NOME$/;
    my $quem = "usuario=$conta origem=$ip";
    return registrar("apagado: $quem arquivo=" . limpo($1, 400)) if $texto =~ /^Deleted (.+)$/s;
    return registrar("renomeado: $quem nomes=" . limpo($1, 800)) if $texto =~ /^File successfully renamed or moved: (\[.+\]->\[.+\])$/s;
    if ($texto =~ m{^(/.+) (uploaded|downloaded)  \((\d{1,20}) bytes, [\d.]+KB/sec\)$}s) {
        my ($caminho, $sentido, $bytes) = ($1, $2, $3);
        if ($sentido eq 'uploaded') {
            atualizar();
            if (defined $destino{$conta}) { $caminho = da_entrada($conta, $caminho); }
            else { entregar($conta, $caminho); }
        }
        return registrar(($sentido eq 'uploaded' ? 'envio' : 'download') . ": $quem bytes=$bytes arquivo=" . limpo($caminho, 400));
    }
}

# Linha do syslog: "<prioridade>Mes DD HH:MM:SS pure-ftpd: (conta@endereco) [NIVEL] texto". O começo é
# escrito pela libc e pelo Pure-FTPd; do cliente só vem o que está depois do nível, e é ali que o nome
# digitado aparece. Por isso a linha é conferida do início ao fim.
sub tratar {
    my ($linha) = @_;
    $linha =~ s/[\r\n\0]+$//;
    return unless $linha =~ /^<(\d{1,3})>[A-Z][a-z]{2} [ \d]\d \d\d:\d\d:\d\d pure-ftpd(?:\[\d+\])?: \(([^@\s]{1,64})\@($ENDERECO)\) \[[A-Z]+\] (.*)$/s;
    my ($gravidade, $conta, $ip, $texto) = ($1 & 7, $2, $3, $4);
    return if $ip =~ /^127\./;   # a conferência de saúde do container
    if ($texto =~ /^Authentication failed for user \[(.*)\]$/s) { return senha_errada($ip, $1); }
    if ($texto =~ /^($NOME) is now logged in$/) { return entrada_certa($ip, $1); }
    return arquivo($conta, $ip, $texto) if $gravidade == 5;
    return if $gravidade > 4;    # aviso e erro seguem para o registro; o resto (conexão e saída) não
    $texto =~ s/[^\x20-\x7e]/?/g;
    registrar('pure-ftpd: ' . substr($texto, 0, 200) . " origem=$ip");
}

# De minuto em minuto: bloqueio vencido, marca de recusa velha e contagem parada saem.
sub limpar {
    my $agora = time;
    if (opendir(my $pasta, $BLOQUEIOS)) {
        for my $item (readdir $pasta) {
            next unless $item =~ /^$NOME\@$ENDERECO$/ || $item =~ /^\.novo\.\d+$/;
            my $caminho = "$BLOQUEIOS/$item";
            if ($item =~ /^\./) {
                my @s = stat($caminho);
                unlink $caminho if @s && $agora - $s[9] > 60;
                next;
            }
            open(my $arq, '<', $caminho) or next;
            my $texto = <$arq> // '';
            close $arq;
            unlink $caminho unless $texto =~ /^(\d{1,12}) / && $1 > $agora;
        }
        closedir $pasta;
    }
    if (opendir(my $pasta, $RECUSAS)) {
        for my $item (readdir $pasta) {
            next if $item =~ /^\.\.?$/;
            my @s = stat("$RECUSAS/$item");
            unlink "$RECUSAS/$item" if @s && $agora - $s[9] > $RECUSA_VALE;
        }
        closedir $pasta;
    }
    for my $chave (keys %falhas) {
        my @dentro = grep { $agora - $_ < 1440 * 60 } @{ $falhas{$chave} };
        if (@dentro) { $falhas{$chave} = \@dentro; } else { delete $falhas{$chave}; }
    }
}

# Contadores de rede deste container, para a aba Servidor do painel, que não enxerga a rede daqui. Uma linha de
# sete números: instante, segundos do intervalo, bytes recebidos e enviados desde que o container subiu, bytes
# recebidos e enviados no intervalo, e erros e descartes. Só grava quando os contadores mudam, e mais uma vez
# quando o tráfego para: FTP parado não escreve em disco. Falha aqui nunca derruba o vigia.
my ($rede_quando, $rede_ativa, @rede_antes) = (0, 0);
sub publicar_rede {
    my $agora = time;
    open(my $arq, '<', '/proc/net/dev') or return;
    my @soma = (0, 0, 0);
    while (my $linha = <$arq>) {
        next unless $linha =~ /^\s*([^\s:]+):\s*(.+)$/ && $1 ne 'lo';
        my @c = split ' ', $2;
        next if @c < 12 || grep { !/^\d{1,20}$/ } @c[0, 2, 3, 8, 10, 11];
        $soma[0] += $c[0];
        $soma[1] += $c[8];
        $soma[2] += $c[2] + $c[3] + $c[10] + $c[11];
    }
    close $arq;
    my @antes = @rede_antes ? @rede_antes : @soma;
    my $intervalo = $rede_quando ? $agora - $rede_quando : 0;
    my ($recebeu, $enviou) = map { $soma[$_] > $antes[$_] ? $soma[$_] - $antes[$_] : 0 } 0, 1;
    my $gravar = !@rede_antes || $rede_ativa || grep { $soma[$_] != $antes[$_] } 0 .. 2;
    ($rede_quando, $rede_ativa, @rede_antes) = ($agora, ($recebeu || $enviou) ? 1 : 0, @soma);
    return unless $gravar;
    publicar($REDE, "$agora $intervalo $soma[0] $soma[1] $recebeu $enviou $soma[2]");
}

# Recursos deste container, para a aba Servidor do painel, que só enxerga os dele. O container lê o próprio cgroup:
# não há soquete do Docker nem pasta do servidor montada para isso. Uma linha de doze números: instante, instante
# em que o vigia iniciou, milissegundos do intervalo, microssegundos de processador gastos nele, cota e período do
# limite de processador (cota 0 = sem limite), memória em uso e limite dela (0 = sem limite), processos e limite
# deles (0 = sem limite), vezes em que o limite de processador segurou o container e vezes em que faltou memória.
# A memória em uso não conta o cache de arquivo que o sistema solta quando precisa. Container parado publica uma
# vez por minuto; com uso, a cada leitura.
my $INICIO = time;
my ($rec_quando, $rec_vezes, @rec_gravado) = (0, 0);
sub do_cgroup {
    my ($nome, $chave) = @_;
    open(my $arq, '<', "$CGROUP/$nome") or return 0;
    local $/;
    my $texto = <$arq>;
    close $arq;
    return 0 unless defined $texto;
    return $texto =~ /^\Q$chave\E (\d{1,20})$/m ? $1 + 0 : 0 if defined $chave;
    return $texto =~ /^(\d{1,20})(?: (\d{1,20}))?$/m ? (wantarray ? ($1 + 0, ($2 // 0) + 0) : $1 + 0) : 0;
}
sub publicar_recursos {
    my $agora = Time::HiRes::time();
    my $cpu = do_cgroup('cpu.stat', 'usage_usec');
    my ($cota, $periodo) = do_cgroup('cpu.max');
    my $memoria = do_cgroup('memory.current') - do_cgroup('memory.stat', 'inactive_file');
    $memoria = 0 if $memoria < 0;
    my @agora = ($cpu, $memoria, scalar do_cgroup('pids.current'), do_cgroup('cpu.stat', 'nr_throttled'),
                 do_cgroup('memory.events', 'oom_kill'));
    my $intervalo = $rec_quando ? int(($agora - $rec_quando) * 1000) : 0;
    my $gasto = @rec_gravado && $cpu > $rec_gravado[0] ? $cpu - $rec_gravado[0] : 0;
    # Vale publicar: as duas primeiras leituras (a segunda é a primeira que traz o uso do processador), um minuto
    # sem publicar, 1% de um núcleo em uso, 1 MiB de diferença na memória, ou mudança nos processos e nos contadores.
    my $gravar = $rec_vezes < 2 || $intervalo >= $RECURSOS_VALE * 1000 || $gasto >= $intervalo * 10
        || abs($memoria - $rec_gravado[1]) >= 1048576 || grep { $agora[$_] != $rec_gravado[$_] } 2 .. 4;
    return unless $gravar;
    my $linha = join(' ', int($agora), $INICIO, $intervalo, $gasto, $cota, $periodo || 0, $memoria,
                     scalar do_cgroup('memory.max'), $agora[2], scalar do_cgroup('pids.max'), @agora[3, 4]);
    return unless publicar($RECURSOS, $linha);
    ($rec_quando, @rec_gravado) = ($agora, @agora);
    $rec_vezes++ if $rec_vezes < 2;
}

# Grava um arquivo de estado de uma linha, por arquivo de passagem e troca de nome. A cópia de segurança lê /auth
# com a trava do cadastro: gravar com ela faz a cópia nunca ver o arquivo de passagem. Trava ocupada: esta leitura
# não é publicada, e a seguinte sai no próximo ciclo. A trava é solta quando a função termina.
sub publicar {
    my ($arquivo, $linha) = @_;
    my $trava;
    if (open($trava, '<', $TRAVA)) { flock($trava, LOCK_EX | LOCK_NB) or return 0; }
    my $novo = "$arquivo.novo";
    open(my $saida, '>', $novo) or return 0;
    print $saida "$linha\n";
    return 1 if close($saida) && rename($novo, $arquivo);
    unlink $novo;
    return 0;
}

$SIG{TERM} = $SIG{INT} = sub { exit 0 };
umask 0077;
ler_redes();
socket(my $escuta, AF_UNIX, SOCK_DGRAM, 0) or die "vigia: FALHA: soquete: $!\n";
unlink $SOQUETE;
bind($escuta, pack_sockaddr_un($SOQUETE)) or die "vigia: FALHA: $SOQUETE não abre: $!\n";
registrar('pronto: ' . ($PADRAO_TENTATIVAS
    ? "$PADRAO_TENTATIVAS senhas erradas do mesmo endereço bloqueiam o usuário para ele por $PADRAO_MINUTOS min"
    : 'bloqueio por tentativa desligado na stack (FTP_BLOQUEIO_TENTATIVAS=0); vale o limite de cada usuário')
    . '; limite próprio do usuário em Editar, na aba Usuários do painel');
my $proxima = time + 60;
my $proxima_rede = time;
while (1) {
    my $pronto = '';
    vec($pronto, fileno($escuta), 1) = 1;
    if (select($pronto, undef, undef, 5) > 0) {
        my $linha = '';
        tratar($linha) if defined recv($escuta, $linha, 8192, 0);
    }
    if (time >= $proxima_rede) {
        publicar_rede();
        publicar_recursos();
        $proxima_rede = time + $REDE_CADA;
    }
    if (time >= $proxima) {
        limpar();
        $proxima = time + 60;
    }
}
