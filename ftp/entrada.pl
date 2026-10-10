#!/usr/bin/perl
# SPDX-License-Identifier: Apache-2.0
# Área de entrada do perfil "só envio" (soenvio): a conta entra no FTP presa em /data/.entrada/<usuario>, fora da
# pasta dos backups, e cada arquivo que termina de chegar é movido daqui para a pasta do usuário, já como
# ftpdata. A conta não alcança a pasta de destino: não lista nem baixa o que está lá, nem o que ela mesma enviou.
#
# Quem move é o vigia do FTP, a cada aviso de envio (entrada_mover). Chamado como programa, com o usuário e a
# pasta de destino, entrega o que ficou na área: é o uso do allsafe-ftp-user na partida do serviço ftp, na
# troca de perfil e na remoção do usuário.
#
# O nome e o caminho do arquivo vêm do cliente. As duas pontas são abertas nível por nível a partir do /data,
# sem seguir link simbólico, e o arquivo é ligado no destino com link(), que não substitui o que já existe: nome
# repetido ganha a data e a hora. Depois de ligado, confere-se que o que chegou ao destino é o arquivo aberto.
use strict;
use warnings;
use Fcntl qw(O_RDONLY O_NOFOLLOW O_DIRECTORY O_NONBLOCK);

my $ENTRADA_DADOS  = '/data';
my $ENTRADA_AREA   = '.entrada';
my ($ENTRADA_UID_DADOS, $ENTRADA_GID_DADOS, $ENTRADA_UID_SOENVIO) = (10000, 10000, 10004);
my $ENTRADA_NIVEIS = 16;     # pastas que o cliente pode ter criado até o arquivo
my $ENTRADA_NOMES  = 99;     # nomes tentados para o arquivo que chega com nome repetido
my $ENTRADA_ITENS  = 20000;  # arquivos entregues em uma varredura da área

# Nomes para o arquivo no destino: o que o cliente deu e, se já existe, o mesmo com a data e a hora antes da
# extensão (backup.rsc ➜ backup-20261009-153000.rsc), e com um número quando até esse se repete.
sub entrada_nomes {
    my ($nome) = @_;
    my ($base, $extensao) = $nome =~ /^(.+?)((?:\.tar)?\.[A-Za-z0-9]{1,10})$/s ? ($1, $2) : ($nome, '');
    my @t = localtime;
    my $marca = sprintf('-%04d%02d%02d-%02d%02d%02d', $t[5] + 1900, $t[4] + 1, @t[3, 2, 1, 0]);
    my @nomes = ($nome);
    for my $vez (1 .. $ENTRADA_NOMES) {
        my $fim = $marca . ($vez > 1 ? "-$vez" : '') . $extensao;
        my $comeco = $base;
        if (length($comeco) + length($fim) > 255) {   # o nome de arquivo tem 255 bytes: quem cede é o começo
            $comeco = substr($comeco, 0, 255 - length($fim));
            $comeco =~ s/[\x80-\xBF]*$//;
            $comeco =~ s/[\xC0-\xFF]$//;              # sem deixar um caractere UTF-8 pela metade
        }
        push @nomes, $comeco . $fim;
    }
    return @nomes;
}

# Move um arquivo da área de entrada da conta para a pasta de destino. $relativo é o caminho dele dentro da
# área. Devolve (caminho final, '') ou (undef, motivo).
sub entrada_mover {
    my ($conta, $destino, $relativo) = @_;
    my @niveis = split m{/}, $relativo, -1;
    my $arquivo = pop @niveis;
    return (undef, 'caminho') if !defined $arquivo || @niveis > $ENTRADA_NIVEIS
        || grep { $_ eq '' || $_ eq '.' || $_ eq '..' } @niveis, $arquivo;
    my ($final, $ligado);
    my $feito = eval {
        # Origem: a pasta do arquivo, dentro da área da conta, e o arquivo aberto.
        chdir($ENTRADA_DADOS) or die "pasta de dados\n";
        my $origem;
        for my $nome ($ENTRADA_AREA, $conta, @niveis) {
            sysopen($origem, $nome, O_RDONLY | O_NOFOLLOW | O_DIRECTORY) or die "pasta de entrada\n";
            chdir($origem) or die "pasta de entrada\n";
        }
        sysopen(my $aberto, $arquivo, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or die "arquivo\n";
        my @dele = stat($aberto) or die "arquivo\n";
        die "arquivo\n" unless -f _ && $dele[3] == 1 && $dele[4] == $ENTRADA_UID_SOENVIO;
        # Destino: a pasta do usuário tem de existir; as de dentro, que o cliente criou na área, nascem aqui com
        # o modo dela.
        chdir($ENTRADA_DADOS) or die "pasta de dados\n";
        my $pasta;
        for my $nome (split m{/}, $destino) {
            sysopen($pasta, $nome, O_RDONLY | O_NOFOLLOW | O_DIRECTORY) or die "pasta de destino\n";
            chdir($pasta) or die "pasta de destino\n";
        }
        my @modo = stat($pasta) or die "pasta de destino\n";
        for my $nome (@niveis) {
            my $dentro;
            if (!sysopen($dentro, $nome, O_RDONLY | O_NOFOLLOW | O_DIRECTORY)) {
                die "pasta de destino\n" unless $!{ENOENT};
                mkdir($nome, 0700) or die "pasta de destino\n";
                sysopen($dentro, $nome, O_RDONLY | O_NOFOLLOW | O_DIRECTORY) or die "pasta de destino\n";
                chown($ENTRADA_UID_DADOS, $ENTRADA_GID_DADOS, $dentro) or die "dono da pasta\n";
                chmod($modo[2] & 07777, $dentro) or die "modo da pasta\n";
            }
            chdir($dentro) or die "pasta de destino\n";
        }
        # O nome de origem é dado pela pasta já aberta: trocar um nível do caminho depois da conferência não
        # leva o link() para outro lugar.
        my $de = '/proc/self/fd/' . fileno($origem) . "/$arquivo";
        for my $nome (entrada_nomes($arquivo)) {
            if (link($de, $nome)) { $final = $nome; last; }
            die "gravar no destino\n" unless $!{EEXIST};
        }
        die "nome livre no destino\n" unless defined $final;
        $ligado = 1;
        my @posto = lstat($final) or die "arquivo trocado\n";
        die "arquivo trocado\n" unless $posto[0] == $dele[0] && $posto[1] == $dele[1];
        chown($ENTRADA_UID_DADOS, $ENTRADA_GID_DADOS, $aberto) or die "dono do arquivo\n";
        $ligado = 0;   # entregue: daqui em diante o que está no destino fica
        my @resto = lstat($de);
        unlink($de) if @resto && $resto[0] == $dele[0] && $resto[1] == $dele[1];
        1;
    };
    my $motivo = $@;
    unlink($final) if $ligado;   # ainda no diretório de destino
    chdir('/');
    return (join('/', $ENTRADA_DADOS, $destino, @niveis, $final), '') if $feito;
    chomp $motivo;
    return (undef, $motivo || 'falha');
}

# Arquivos comuns que estão na área da conta, pelo caminho dentro dela. Só a lista: quem confere é o entrada_mover.
sub entrada_restos {
    my ($conta) = @_;
    my (@achados, @fila);
    @fila = ('');
    while (@fila && @achados < $ENTRADA_ITENS) {
        my $dentro = shift @fila;
        opendir(my $pasta, "$ENTRADA_DADOS/$ENTRADA_AREA/$conta$dentro") or next;
        for my $nome (sort grep { $_ ne '.' && $_ ne '..' } readdir $pasta) {
            my @dele = lstat("$ENTRADA_DADOS/$ENTRADA_AREA/$conta$dentro/$nome") or next;
            if (-d _) { push @fila, "$dentro/$nome" if ($dentro =~ tr{/}{}) < $ENTRADA_NIVEIS; }
            elsif (-f _) { push @achados, substr("$dentro/$nome", 1); }
        }
        closedir $pasta;
    }
    return @achados;
}

# Como programa: entrega o que ficou na área de entrada do usuário. Sai com 1 se algo não pôde ser entregue.
unless (caller) {
    my ($conta, $destino) = @ARGV;
    my $nivel = qr/[A-Za-z0-9_][A-Za-z0-9._-]{0,63}/;
    die "Uso: $0 <usuario> <pasta de destino>\n" unless @ARGV == 2 && $conta =~ /^[a-z_][a-z0-9_-]{0,31}$/
        && $destino =~ m{^$nivel(?:/$nivel){0,3}$};
    my $falhas = 0;
    for my $relativo (entrada_restos($conta)) {
        my ($final, $motivo) = entrada_mover($conta, $destino, $relativo);
        next if defined $final;
        $relativo =~ s/[^\x20-\x7e]/?/g;
        print STDERR "Entrega nao feita ($motivo): $ENTRADA_DADOS/$ENTRADA_AREA/$conta/" . substr($relativo, 0, 400) . "\n";
        $falhas++;
    }
    exit($falhas ? 1 : 0);
}

1;
