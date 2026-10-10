#!/usr/bin/perl
# SPDX-License-Identifier: Apache-2.0
# Endereço e prefixo do bloqueio por endereço, IPv4 e IPv6, lidos e escritos de um jeito só.
#
# O bloqueio é um arquivo com o nome do endereço (/auth/enderecos) ou do prefixo (/auth/prefixos, com "_" no
# lugar da barra). Para o nome servir, cada endereço tem uma escrita só: a que sai daqui. É a mesma do painel
# (ipaddress do Python), e a bateria confere as duas uma contra a outra.
#
#   IPv4:  quatro números de 0 a 255, sem zero à esquerda;
#   IPv6:  minúsculo, com a maior sequência de zeros comprimida (inet_ntop);
#   IPv4 dentro de IPv6 (::ffff:a.b.c.d): vale o IPv4;
#   prefixo: <rede>/<tamanho>, com a rede já sem os bits depois do tamanho. IPv4 de /8 a /31, IPv6 de /16 a
#          /127: o endereço sozinho é bloqueado como endereço, e prefixo maior que isso pega redes demais.
#
# Nunca é bloqueado o que é do próprio servidor: 127.0.0.0/8 e 0.0.0.0/8 no IPv4 e ::/16 no IPv6, onde ficam o
# ::1, o endereço vazio e as formas antigas de escrever IPv4.
#
# Usam este arquivo o vigia e o porteiro do FTP (require) e o allsafe-ftp-user, que o chama como programa.
use strict;
use warnings;
use Socket qw(AF_INET AF_INET6 inet_pton inet_ntop);

my $ENDERECO_IPV4 = qr/(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])/;

# Texto ➜ (família, bits): 4 e 32 bits ou 6 e 128 bits, em texto de zeros e uns. Lista vazia se não é endereço.
sub endereco_ler {
    my ($texto) = @_;
    return () unless defined $texto && $texto =~ /^[0-9A-Fa-f.:]{2,45}\z/;
    return (4, unpack('B32', inet_pton(AF_INET, $texto))) if $texto =~ /^$ENDERECO_IPV4\z/;
    return () unless $texto =~ /:/;
    my $bytes = eval { inet_pton(AF_INET6, $texto) };
    return () unless defined $bytes && length($bytes) == 16;
    return (4, unpack('B32', substr($bytes, 12))) if substr($bytes, 0, 12) eq ("\0" x 10) . "\xff\xff";
    return (6, unpack('B128', $bytes));
}

sub endereco_escrever {
    my ($familia, $bits) = @_;
    return inet_ntop($familia == 4 ? AF_INET : AF_INET6, pack('B*', $bits));
}

# Do próprio servidor: nunca vira bloqueio. Vale para o endereço e para a rede de um prefixo.
sub endereco_do_servidor {
    my ($familia, $bits) = @_;
    return $familia == 4 ? $bits =~ /^(?:00000000|01111111)/ : $bits =~ /^0{16}/;
}

# A escrita única do endereço, ou undef se o texto não é um endereço que pode ser bloqueado.
sub endereco_canonico {
    my ($familia, $bits) = endereco_ler($_[0]) or return undef;
    return undef if endereco_do_servidor($familia, $bits);
    return endereco_escrever($familia, $bits);
}

# "rede/tamanho" ➜ (família, bits da rede, só os do tamanho, tamanho). Lista vazia se não é prefixo aceito.
sub prefixo_ler {
    my ($texto) = @_;
    return () unless defined $texto && $texto =~ m{^([^/]+)/([1-9][0-9]{0,2})\z};
    my $tamanho = $2;
    my ($familia, $bits) = endereco_ler($1) or return ();
    return () if $tamanho < ($familia == 4 ? 8 : 16) || $tamanho > ($familia == 4 ? 31 : 127);
    return ($familia, substr($bits, 0, $tamanho), $tamanho);
}

# A escrita única do prefixo, com a rede sem os bits depois do tamanho, ou undef.
sub prefixo_canonico {
    my ($familia, $rede, $tamanho) = prefixo_ler($_[0]) or return undef;
    return undef if endereco_do_servidor($familia, $rede);
    return endereco_escrever($familia, $rede . '0' x (($familia == 4 ? 32 : 128) - $tamanho)) . "/$tamanho";
}

# O bloqueio gravado no arquivo ainda vale. Linha: <vale até> <desde> <erros> <quem bloqueou>.
sub bloqueio_vale {
    my ($caminho) = @_;
    return 0 if -l $caminho;
    open(my $arq, '<', $caminho) or return 0;
    my $linha = <$arq> // '';
    close $arq;
    return $linha =~ /^(\d{1,12}) / && $1 > time ? 1 : 0;
}

# Prefixo bloqueado, ainda valendo, que cobre o endereço: o texto dele, ou undef. A pasta é pequena (o
# allsafe-ftp-user e o painel não passam de mil prefixos) e quase sempre vazia.
sub prefixo_que_cobre {
    my ($pasta, $endereco) = @_;
    my ($familia, $bits) = endereco_ler($endereco) or return undef;
    opendir(my $aberta, $pasta) or return undef;
    my @nomes = grep { !/^\./ } readdir $aberta;
    closedir $aberta;
    for my $nome (@nomes) {
        (my $texto = $nome) =~ s{_}{/};
        my ($dele, $rede, $tamanho) = prefixo_ler($texto) or next;
        next unless $dele == $familia && substr($bits, 0, $tamanho) eq $rede;
        return $texto if bloqueio_vale("$pasta/$nome");
    }
    return undef;
}

# Como programa: diz o que o texto é e a escrita única dele.
#   endereco.pl alvo <texto>   ➜ "endereco <endereço>" ou "prefixo <rede>/<tamanho>"
# Sai com 1 se o texto não é endereço nem prefixo, e com 2 se é do próprio servidor.
unless (caller) {
    die "Uso: $0 alvo <endereco ou prefixo>\n" unless @ARGV == 2 && $ARGV[0] eq 'alvo';
    my $texto = $ARGV[1];
    my ($tipo, $familia, $bits, $tamanho) = ('endereco', endereco_ler($texto));
    ($tipo, $familia, $bits, $tamanho) = ('prefixo', prefixo_ler($texto)) unless defined $familia;
    exit 1 unless defined $familia;
    exit 2 if endereco_do_servidor($familia, $bits);
    print "$tipo ", ($tipo eq 'endereco' ? endereco_canonico($texto) : prefixo_canonico($texto)), "\n";
    exit 0;
}

1;
