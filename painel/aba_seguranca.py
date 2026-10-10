# SPDX-License-Identifier: Apache-2.0
"""Aba Segurança: o que o painel consegue conferir da própria stack."""
import os

import enderecos
from config import ARQ_CERT, ARQ_CERT_FTP, CFG, FALHAS_MAX, PRIVADAS, endereco_privado
from estado import bloqueios, certificado, sem_tls, senhas_de_custo_antigo
from graficos import faixa
from icones import icone
from idioma import t, tn
from pagina import alerta_tls, aviso_rede, cabeca, data_inteira, e, marca, pagina, validade


def seguranca(pedido, sessao, consulta, formulario, token):
    tls = {'0': ('atencao', t('<strong>desligado</strong>: senhas e arquivos trafegam em texto puro. Só para equipamento '
                              'sem suporte a TLS, em rede interna isolada.')),
           '1': ('atencao', t('opcional: aceita login sem criptografia. Use só com equipamento legado.')),
           '2': ('bom', t('obrigatório no login; os dados seguem o que o cliente pedir.')),
           '3': ('bom', t('obrigatório no login e nos dados.'))}
    marca_tls, texto_tls = tls.get(CFG['ftp_tls'], ('atencao', t('modo desconhecido')))
    if CFG['tls_excecoes']:
        marcados = sem_tls()
        if marcados:
            marca_tls = 'atencao'
            texto_tls += ' ' + t('<strong>Exceção por usuário ligada</strong> (<code>FTP_TLS_EXCECOES=sim</code>): {quantos} '
                                 'usuário(s) entram sem TLS, com senha e arquivos em texto puro: {nomes}. '
                                 'Quem tenta entrar sem TLS sem estar dispensado é recusado, mas a senha já passou em texto puro: '
                                 'o log do FTP registra a tentativa.', quantos=len(marcados), nomes=e(', '.join(marcados)))
        else:
            texto_tls += ' ' + t('Exceção por usuário ligada (<code>FTP_TLS_EXCECOES=sim</code>), sem nenhum usuário dispensado: '
                                 'todos entram com TLS, e a sessão sem TLS é recusada antes de a senha ser enviada. A dispensa de '
                                 'um equipamento sem suporte a TLS é feita em <a href="/usuarios">Usuários</a>.')
    elif CFG['ftp_tls'] in ('2', '3'):
        texto_tls += ' ' + t('Sem exceção por usuário: {motivo}.', motivo=t(CFG['tls_sem_excecao']))
    cert_ftp, cert_painel = certificado(ARQ_CERT_FTP), certificado(ARQ_CERT)
    marca_ftp, validade_ftp = validade(cert_ftp)
    marca_painel, validade_painel = validade(cert_painel)
    somente_leitura = not os.access('/', os.W_OK)
    sem_docker = not os.path.exists('/var/run/docker.sock') and not os.path.exists('/run/docker.sock')
    redes = ', '.join(str(rede) for rede in CFG['redes'])
    antigas = senhas_de_custo_antigo()
    presos = bloqueios()
    presos_endereco = enderecos.lista()

    def local(ip):
        if ip.startswith('127.'):
            return t('IP privado, só o próprio host alcança')
        if endereco_privado(ip):
            return t('IP privado, alcançável pela rede interna deste endereço')
        return t('<strong>IP público</strong>: alcançável pela internet se o firewall não barrar')

    def marca_ip(ip):
        return 'bom' if endereco_privado(ip) else 'atencao'
    redes_publicas = [str(rede) for rede in CFG['redes'] if not any(rede.subnet_of(p) for p in PRIVADAS)]

    estados = []

    def linha(estado, item, situacao):
        estados.append(estado)
        return f'<tr><td class="marca">{marca(estado)}</td><th scope="row">{item}</th><td>{situacao}</td></tr>'
    # Aviso de exposição oculto por opção de quem instalou: a linha da própria opção diz que ele está oculto.
    oculto = ('' if CFG['aviso_exposicao'] else
              ' ' + t('O aviso do menu, do rodapé e do começo desta aba está oculto (<code>PAINEL_AVISO_EXPOSICAO=nao</code>).'))
    itens = [
        linha('atencao' if CFG['ip_publico'] else 'bom', t('Endereço público'),
              (t('<strong>Aceito</strong> (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>): a proteção contra a internet passa a ser o '
                 'firewall do servidor, o TLS obrigatório e as senhas geradas.') + oculto) if CFG['ip_publico']
              else t('Recusado por código (<code>REDE_PERMITIR_IP_PUBLICO=nao</code>): FTP e painel só escutam em IP privado. '
                     'Aceitar é opção de quem instala.')),
        linha('atencao' if CFG['proxies'] else 'neutro', t('Painel por proxy ou túnel'),
              (t('<strong>Em uso</strong> (<code>PAINEL_PROXY_CONFIAVEL={proxies}</code>): o endereço de quem acessa é o que o proxy '
                 'informa em <code>X-Forwarded-For</code>, e é ele que conta as senhas erradas, prende a sessão e vai para a '
                 'auditoria. Quem pode chegar à tela de entrada é decidido no proxy ou no túnel. O FTP não passa por ele.',
                 proxies=e(','.join(str(proxy) for proxy in CFG['proxies']))) + oculto)
              if CFG['proxies'] else
              t('Não usado (<code>PAINEL_PROXY_CONFIAVEL</code> vazio): o endereço do cliente é sempre o da conexão, e '
                '<code>X-Forwarded-For</code> é ignorado. Publicar só o painel por proxy ou túnel é opção de quem instala.')),
        linha(marca_ip(CFG['ftp_bind']), t('Endereço do FTP'),
              f'<code>{e(CFG["ftp_bind"])}:{e(CFG["ftp_porta"])}</code> — {local(CFG["ftp_bind"])}.'),
        linha(marca_ip(CFG['ftp_anunciado']), t('IP anunciado no modo passivo'), f'<code>{e(CFG["ftp_anunciado"])}</code> — '
              + (t('IP privado.') if endereco_privado(CFG['ftp_anunciado']) else t('<strong>IP público</strong>.'))),
        linha(marca_tls, t('TLS do FTP'), f'{t("Modo")} <code>{e(CFG["ftp_tls"])}</code>: {texto_tls}'),
        linha(marca_ftp, t('Certificado do FTP'), f'{data_inteira(e(validade_ftp))}<br><span class="suave">SHA-256</span> '
              f'<code>{e(cert_ftp["digital"] if cert_ftp else "—")}</code>'),
        linha(marca_ip(CFG['painel_bind']), t('Endereço do painel'),
              f'<code>{e(CFG["painel_bind"])}:{e(CFG["painel_porta"])}</code> — {t("só HTTPS")}, {local(CFG["painel_bind"])}.'),
        linha('bom', t('Frente web'), t('O navegador fala com o nginx, a única porta publicada do painel: ele fecha o HTTPS, '
                                        'limita redes e taxa de pedidos e repassa por soquete Unix. O painel não escuta em porta de rede.')),
        linha(marca_painel, t('Certificado do painel'), f'{data_inteira(e(validade_painel))}<br><span class="suave">SHA-256</span> '
              f'<code>{e(cert_painel["digital"] if cert_painel else "—")}</code>'),
        linha('atencao' if redes_publicas else 'bom', t('Quem pode abrir o painel'),
              t('Clientes de <code>{redes}</code>; os demais são recusados pelo nginx, antes de chegar ao painel.', redes=e(redes))
              + (' ' + t('<strong>Rede pública na lista: {redes}.</strong>', redes=e(', '.join(redes_publicas))) if redes_publicas else '')),
        linha('bom', t('Sessão'), t('Encerra com {minutos} minutos sem uso e, de qualquer forma, em 8 horas. '
                                    '{falhas} entradas erradas bloqueiam o endereço por 15 minutos.',
                                    minutos=CFG['inatividade'] // 60, falhas=FALHAS_MAX)),
        linha('atencao' if CFG['acesso_usuarios'] and CFG['ftp_tls'] == '0' else 'bom', t('Entrada dos usuários do FTP'),
              (t('Ligada (<code>PAINEL_ACESSO_USUARIOS_FTP=sim</code>): cada usuário do FTP entra com o nome e a senha do FTP e só '
                 'navega e baixa na pasta dele. Quem confere a senha é o próprio servidor FTP, pela rede interna da stack,') + ' '
               + (t('<strong>em texto puro</strong>, porque o FTP está sem TLS.') if CFG['ftp_tls'] == '0'
                  else t('em TLS e com o certificado dele conferido.'))) if CFG['acesso_usuarios']
              else t('Desligada (<code>PAINEL_ACESSO_USUARIOS_FTP=nao</code>): só administrador entra no painel.')),
        linha('bom' if CFG['bloqueio_tentativas'] else 'atencao', t('Bloqueio por tentativa no FTP'),
              (t('{tentativas} senhas erradas do mesmo endereço bloqueiam o usuário para aquele endereço por {minutos} minutos '
                 '(<code>FTP_BLOQUEIO_TENTATIVAS</code> e <code>FTP_BLOQUEIO_MINUTOS</code>).',
                 tentativas=CFG['bloqueio_tentativas'], minutos=CFG['bloqueio_minutos'])
               if CFG['bloqueio_tentativas'] else
               t('<strong>Desligado na stack</strong> (<code>FTP_BLOQUEIO_TENTATIVAS=0</code>): só é bloqueado o usuário que tem limite próprio.'))
              + ' ' + t('O limite próprio de cada usuário fica em Editar, na aba Usuários.') + ' '
              + (t('<strong>Bloqueado agora: {nomes}.</strong>', nomes=e(', '.join(sorted(presos)))) if presos
                 else t('Nenhum usuário bloqueado agora.'))),
        linha('bom' if CFG['endereco_erros'] else 'atencao', t('Bloqueio por endereço'),
              (t('O endereço que passa de {erros} de usuário e senha em {horas}, no FTP ou no painel, fica {dias} sem entrar nos '
                 'dois (<code>BLOQUEIO_ENDERECO_ERROS</code>, <code>BLOQUEIO_ENDERECO_HORAS</code> e <code>BLOQUEIO_ENDERECO_DIAS</code>).',
                 erros=tn(CFG['endereco_erros'], '{n} erro', '{n} erros'),
                 horas=tn(CFG['endereco_janela'] // 3600, '{n} hora', '{n} horas'),
                 dias=tn(CFG['endereco_dias'], '{n} dia', '{n} dias'))
               if CFG['endereco_erros'] else
               t('<strong>Desligado na stack</strong> (<code>BLOQUEIO_ENDERECO_ERROS=0</code>): nenhum endereço é bloqueado sozinho.'))
              + ' ' + ('<strong><a href="/bloqueios">'
                       + tn(len(presos_endereco), '{n} endereço bloqueado agora', '{n} endereços bloqueados agora')
                       + '</a>.</strong>' if presos_endereco else t('Nenhum endereço bloqueado agora.'))),
        linha('atencao' if antigas else 'bom', t('Custo das senhas do FTP'),
              t('<strong>{quantos} usuário(s) com a senha gravada com o custo anterior</strong>: {nomes}. '
                'Cada tentativa de entrada com esses nomes ocupa mais o processador do FTP. O custo atual passa a valer '
                'quando a senha é trocada, na aba Usuários.', quantos=len(antigas), nomes=e(', '.join(antigas))) if antigas
              else t('Todas as senhas estão gravadas com o custo do porte atual (<code>FTP_MAX_CLIENTS</code>).')),
        linha('bom' if CFG['contato_seguranca'] else ('atencao' if CFG['ip_publico'] else 'neutro'), t('Contato de segurança'),
              t('Publicado em <code>/.well-known/security.txt</code>: quem achar uma falha nesta instalação escreve para '
                '<code>{contato}</code>.', contato=e(CFG['contato_seguranca'])) if CFG['contato_seguranca']
              else (t('Não publicado (<code>SEGURANCA_CONTATO_EMAIL</code> vazio): quem achar uma falha nesta instalação não tem '
                      'para onde escrever.')
                    + (' ' + t('<strong>Com endereço público aceito, preencha.</strong>') if CFG['ip_publico'] else ''))),
        linha('bom' if somente_leitura else 'atencao', t('Container do painel'),
              (t('Raiz somente leitura') if somente_leitura else t('Raiz gravável: confira o <code>read_only</code>'))
              + (' ' + t('e sem acesso ao Docker do host.') if sem_docker
                 else '. ' + t('<strong>Há um socket do Docker montado: remova.</strong>'))),
        linha('manual', t('Firewall do host'),
              t('O painel não enxerga o firewall. Confira você: as portas do FTP e do painel devem '
                'estar liberadas só para os endereços que precisam, na cadeia <code>DOCKER-USER</code>')
              + ('. ' + t('<strong>Com endereço público aceito, é o firewall que separa a stack da internet.</strong>') if CFG['ip_publico']
                 else ', ' + t('e nenhuma delas pode ser redirecionada da internet.'))),
    ]
    pedido.enviar(200, pagina(t('Segurança'), f"""{cabeca('Segurança', t('O que protege o servidor nesta instalação, conferido agora.'))}
{aviso_rede()}
{alerta_tls()}
<section class="cartao" aria-label="{t('Resumo da conferência')}"><h2>{icone('escudo')}{t('{quantos} itens conferidos', quantos=len(estados))}</h2>
{faixa((('bom', estados.count('bom'), t('em ordem')), ('atencao', estados.count('atencao'), t('pedem atenção')),
        ('ruim', estados.count('ruim'), t('com problema')),
        ('neutro', estados.count('neutro') + estados.count('manual'), t('que o painel não confere ou não se aplicam'))))}
</section>
<section class="cartao lista"><div class="rolagem"><table class="conferencia"><tbody>{''.join(itens)}</tbody></table></div></section>
<p class="suave">{t('Confira a impressão digital com a que o navegador e o cliente FTP mostram antes de aceitar o certificado.')}</p>""",
                              sessao, '/seguranca'))
