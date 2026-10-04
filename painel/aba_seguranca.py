"""Aba Segurança: o que o painel consegue conferir da própria stack."""
import os

from config import ARQ_CERT, ARQ_CERT_FTP, CFG, FALHAS_MAX, PRIVADAS, endereco_privado
from estado import certificado
from pagina import alerta_tls, aviso_rede, e, pagina, validade


def seguranca(pedido, sessao, consulta, formulario, token):
    tls = {'0': ('⚠️', '<strong>desligado</strong>: senhas e arquivos trafegam em texto puro. Só para equipamento '
                 'sem suporte a TLS, em rede interna isolada.'),
           '1': ('⚠️', 'opcional: aceita login sem criptografia. Use só com equipamento legado.'),
           '2': ('✅', 'obrigatório no login; os dados seguem o que o cliente pedir.'),
           '3': ('✅', 'obrigatório no login e nos dados.')}
    marca_tls, texto_tls = tls.get(CFG['ftp_tls'], ('⚠️', 'modo desconhecido'))
    cert_ftp, cert_painel = certificado(ARQ_CERT_FTP), certificado(ARQ_CERT)
    marca_ftp, validade_ftp = validade(cert_ftp)
    marca_painel, validade_painel = validade(cert_painel)
    somente_leitura = not os.access('/', os.W_OK)
    sem_docker = not os.path.exists('/var/run/docker.sock') and not os.path.exists('/run/docker.sock')
    redes = ', '.join(str(rede) for rede in CFG['redes'])

    def local(ip):
        if ip.startswith('127.'):
            return 'IP privado, só o próprio host alcança'
        if endereco_privado(ip):
            return 'IP privado, alcançável pela rede interna deste endereço'
        return '<strong>IP público</strong>: alcançável pela internet se o firewall não barrar'

    def marca_ip(ip):
        return '✅' if endereco_privado(ip) else '⚠️'
    redes_publicas = [str(rede) for rede in CFG['redes'] if not any(rede.subnet_of(p) for p in PRIVADAS)]

    def linha(marca, item, situacao):
        return f'<tr><td class="marca">{marca}</td><th scope="row">{item}</th><td>{situacao}</td></tr>'
    itens = [
        linha('⚠️' if CFG['ip_publico'] else '✅', 'Endereço público',
              ('<strong>Aceito</strong> (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>): a proteção contra a internet passa a ser o '
               'firewall do servidor, o TLS obrigatório e as senhas geradas.') if CFG['ip_publico']
              else 'Recusado por código (<code>REDE_PERMITIR_IP_PUBLICO=nao</code>): FTP e painel só escutam em IP privado.'),
        linha(marca_ip(CFG['ftp_bind']), 'Endereço do FTP', f'<code>{e(CFG["ftp_bind"])}:{e(CFG["ftp_porta"])}</code> — {local(CFG["ftp_bind"])}.'),
        linha(marca_ip(CFG['ftp_anunciado']), 'IP anunciado no modo passivo', f'<code>{e(CFG["ftp_anunciado"])}</code> — '
              + ('IP privado.' if endereco_privado(CFG['ftp_anunciado']) else '<strong>IP público</strong>.')),
        linha(marca_tls, 'TLS do FTP', f'Modo <code>{e(CFG["ftp_tls"])}</code>: {texto_tls}'),
        linha(marca_ftp, 'Certificado do FTP', f'{e(validade_ftp)}<br><span class="suave">SHA-256</span> '
              f'<code class="digital">{e(cert_ftp["digital"] if cert_ftp else "—")}</code>'),
        linha(marca_ip(CFG['painel_bind']), 'Endereço do painel', f'<code>{e(CFG["painel_bind"])}:{e(CFG["painel_porta"])}</code> — só HTTPS, '
              f'{local(CFG["painel_bind"])}.'),
        linha('✅', 'Frente web', 'O navegador fala com o nginx, a única porta publicada do painel: ele fecha o HTTPS, '
              'limita redes e taxa de pedidos e repassa por soquete Unix. O painel não escuta em porta de rede.'),
        linha(marca_painel, 'Certificado do painel', f'{e(validade_painel)}<br><span class="suave">SHA-256</span> '
              f'<code class="digital">{e(cert_painel["digital"] if cert_painel else "—")}</code>'),
        linha('⚠️' if redes_publicas else '✅', 'Quem pode abrir o painel',
              f'Clientes de <code>{e(redes)}</code>; os demais são recusados pelo nginx, antes de chegar ao painel.'
              + (f' <strong>Rede pública na lista: {e(", ".join(redes_publicas))}.</strong>' if redes_publicas else '')),
        linha('✅', 'Sessão', f'Encerra com {CFG["inatividade"] // 60} minutos sem uso e, de qualquer forma, em 8 horas. '
              f'{FALHAS_MAX} senhas erradas bloqueiam o endereço por 15 minutos.'),
        linha('✅' if somente_leitura else '⚠️', 'Container do painel',
              ('Raiz somente leitura' if somente_leitura else 'Raiz gravável: confira o <code>read_only</code>')
              + (' e sem acesso ao Docker do host.' if sem_docker else '. <strong>Há um socket do Docker montado: remova.</strong>')),
        linha('🧱', 'Firewall do host', 'O painel não enxerga o firewall. Confira você: as portas do FTP e do painel devem '
              'estar liberadas só para os endereços que precisam, na cadeia <code>DOCKER-USER</code>'
              + ('. <strong>Com endereço público aceito, é o firewall que separa a stack da internet.</strong>' if CFG['ip_publico']
                 else ', e nenhuma delas pode ser redirecionada da internet.')),
    ]
    pedido.enviar(200, pagina('Segurança', f'''<h1>🔐 Segurança</h1>
{aviso_rede()}
{alerta_tls()}
<section class="cartao"><div class="rolagem"><table class="conferencia"><tbody>{''.join(itens)}</tbody></table></div></section>
<p class="suave">Confira a impressão digital com a que o navegador e o cliente FTP mostram antes de aceitar o certificado.</p>''',
                            sessao, '/seguranca'))
