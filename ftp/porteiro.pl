#!/usr/bin/perl
# SPDX-License-Identifier: Apache-2.0
# Porteiro do FTP. O pure-authd chama este programa a cada entrada, antes da conferência da senha.
# Ele não confere senha: só decide se a sessão pode seguir para ela.
#   auth_ok:0   "não é comigo": o pure-ftpd segue para o PureDB, que confere a senha;
#   auth_ok:-1  recusa definitiva: o cliente recebe 530, com a senha certa ou errada.
# Três regras, nesta ordem:
#   bloqueio por endereço: a origem, IPv4 ou IPv6, com /auth/enderecos/<origem> ainda valendo, ou coberta por
#     um prefixo de /auth/prefixos ainda valendo, é recusada com qualquer conta, com ou sem TLS. O endereço é
#     gravado pelo vigia, pelo painel e pelo administrador (allsafe-ftp-user endereco-bloquear); o prefixo, só
#     pelo administrador. Apagar o arquivo libera;
#   TLS por usuário (só com a opção valendo, que o entrypoint marca em /run/allsafe/tls-por-usuario):
#     com TLS toda conta segue; sem TLS, só a que o administrador marcou em /auth/sem-tls.lista. Sem nenhum
#     dispensado o pure-ftpd nem chega aqui com sessão sem TLS: ele a recusa antes da senha;
#   bloqueio por tentativa: a conta com /auth/bloqueios/<conta>@<origem> ainda valendo é recusada. Quem
#     grava esse arquivo é o vigia (allsafe-ftp-vigia), que conta as senhas erradas; apagá-lo desbloqueia.
# A origem é lida e escrita do mesmo jeito que no vigia e no painel (endereco.pl): é o nome dos arquivos.
# A senha chega em AUTHD_PASSWORD e não é lida, gravada nem registrada aqui.
use strict;
use warnings;
require '/usr/local/lib/allsafe/endereco.pl';

my $LISTA = '/auth/sem-tls.lista';
my $conta = $ENV{AUTHD_ACCOUNT} // '';
my ($familia, $bits) = endereco_ler($ENV{AUTHD_REMOTE_IP} // '');
my $origem = defined $familia ? endereco_escrever($familia, $bits) : '?';
# O que o cliente mandou como nome pode ser qualquer coisa: só vira caminho ou registro o nome que cabe na regra.
my $nome_valido = $conta =~ /^[a-z_][a-z0-9_-]{0,31}\z/ ? 1 : 0;

sub dispensada {   # a conta está, em linha inteira, na lista de quem entra sem TLS
    open(my $arq, '<', $LISTA) or return 0;
    while (my $linha = <$arq>) {
        chomp $linha;
        return 1 if $linha eq $conta;
    }
    return 0;
}

my $resposta = 0;
if (defined $familia && !endereco_do_servidor($familia, $bits)
    && (bloqueio_vale("/auth/enderecos/$origem") || defined prefixo_que_cobre('/auth/prefixos', $origem))) {
    $resposta = -1;
} elsif (-e '/run/allsafe/tls-por-usuario' && ($ENV{AUTHD_ENCRYPTED} // '0') ne '1' && !($nome_valido && dispensada())) {
    $resposta = -1;
    if ($nome_valido) {
        # Marca para o vigia: esta recusa não é senha errada e não conta para o bloqueio.
        if ($origem ne '?' && open(my $marca, '>', "/run/allsafe/recusa/$origem\@$conta.$$")) { close $marca; }
    } else {
        $conta = '(nome fora da regra)';
    }
    # O pure-authd fecha a saída de erro de quem ele chama: o registro vai pela do processo 1, que é a do container.
    if (open(my $registro, '>', '/proc/1/fd/2')) {
        print $registro "porteiro: entrada sem TLS recusada: usuario=$conta origem=$origem (a senha enviada passou em texto puro: troque-a)\n";
        close $registro;
    }
} elsif ($nome_valido && $origem ne '?' && bloqueio_vale("/auth/bloqueios/$conta\@$origem")) {
    $resposta = -1;
}
print "auth_ok:$resposta\nend\n";
