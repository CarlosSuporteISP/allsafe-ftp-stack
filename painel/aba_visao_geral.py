"""Aba Visão geral: situação do FTP e os dados para configurar o equipamento."""
import shutil

from config import ARQ_CERT_FTP, CFG, PASTA_DADOS
from estado import certificado, ftp_no_ar, uso_da_pasta, usuarios
from pagina import alerta_tls, e, pagina, quando, tamanho, validade


def visao_geral(pedido, sessao, consulta, formulario, token):
    nomes = usuarios()
    usos = [uso_da_pasta(nome) for nome in nomes]
    total = sum(u['bytes'] for u in usos)
    ultimo = max((u['ultimo'] for u in usos), default=0)
    no_ar = ftp_no_ar()
    marca, texto_cert = validade(certificado(ARQ_CERT_FTP))
    try:
        livre = tamanho(shutil.disk_usage(PASTA_DADOS).free) + ' livres no disco'
    except OSError:
        livre = ''
    tls = {'0': '⚠️ Sem TLS: texto puro', '1': '⚠️ TLS opcional: aceita texto puro',
           '2': 'TLS obrigatório no login', '3': 'TLS obrigatório no login e nos dados'}
    protocolo = {'0': 'FTP sem TLS (texto puro), modo passivo',
                 '1': 'FTPS explícito (FTP com TLS) ou, só para equipamento sem TLS, FTP em texto puro; modo passivo',
                 '3': 'FTPS explícito (FTP com TLS), também no canal de dados; modo passivo'}
    pedido.enviar(200, pagina('Visão geral', f'''<h1>📊 Visão geral</h1>
{alerta_tls()}
<div class="grade">
<section class="cartao"><h2>⚙️ Servidor FTP</h2><p class="numero {'bom' if no_ar else 'ruim'}">{'🟢 No ar' if no_ar else '🔴 Fora do ar'}</p>
<p class="suave">{e(tls.get(CFG['ftp_tls'], 'modo TLS ' + CFG['ftp_tls']))}</p></section>
<section class="cartao"><h2>👥 Usuários</h2><p class="numero">{len(nomes)}</p><p class="suave"><a href="/usuarios">ver a lista</a></p></section>
<section class="cartao"><h2>💽 Espaço usado</h2><p class="numero">{e(tamanho(total))}</p><p class="suave">{e(livre)}</p></section>
<section class="cartao"><h2>📥 Último envio</h2><p class="numero menor">{e(quando(ultimo))}</p><p class="suave">arquivo mais novo nas pastas</p></section>
<section class="cartao"><h2>🔐 Certificado do FTP</h2><p class="numero menor">{marca} {e(texto_cert)}</p><p class="suave"><a href="/seguranca">conferir a impressão digital</a></p></section>
</div>
<section class="cartao"><h2>📡 Dados para configurar o equipamento</h2>
<table><tbody>
<tr><th scope="row">Servidor</th><td><code>{e(CFG['ftp_anunciado'])}</code></td></tr>
<tr><th scope="row">Porta de controle</th><td><code>{e(CFG['ftp_porta'])}</code>/tcp</td></tr>
<tr><th scope="row">Portas passivas</th><td><code>{e(CFG['ftp_passiva'])}</code>/tcp</td></tr>
<tr><th scope="row">Protocolo</th><td>{e(protocolo.get(CFG['ftp_tls'], 'FTPS explícito (FTP com TLS), modo passivo'))}</td></tr>
<tr><th scope="row">Usuário e senha</th><td>um usuário por equipamento ou por grupo, criado em <a href="/usuarios">👥 Usuários</a></td></tr>
</tbody></table></section>''', sessao, '/'))
