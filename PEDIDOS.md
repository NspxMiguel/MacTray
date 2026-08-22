# Pedidos — MacTray

## 21/08/2026

- [x] *"cria um tray tipo o do windows pro mac tlg? pra quando a menu bar tiver cheia,
  ter tipo o do windows q tem uma cetinha pra mostrar. um exemplo é a minha q ta cheia,
  ai n aparece os outros apps"*
  - print anexado: menu bar dele lotada (OpenAI, Shottr, velocidade, Bartender-like,
    Figma, Claude, Bluetooth, player, cama, Wi-Fi, bateria 90%, relógio) — com o notch
    do MacBook cortando o resto.
  - **Entregue em 21/08/2026.** App instalado em `/Applications/MacTray.app`, publicado
    em <https://github.com/NspxMiguel/MacTray> e em <https://www.nspx.dev/MacTray/>,
    com card e foto na vitrine. Releases v1.0.0 e v1.0.1.
  - Testado na barra dele: fechado sobra só a seta; um clique traz de volta Shottr,
    Figma, Claude, Bluetooth, player, cama e Wi-Fi. Menu do botão direito, atalho
    global ⌥⌘T, auto-esconder por tempo e as três abas de preferências conferidos em
    tela, em português.

## 21/08/2026 — segunda rodada

- [x] *"tipo oq era o ice, soq o ice ficou horrivel nos novos macos, cheio de bug. ai tem
  a opção de ocultar tudo, ou o tray igual do windows, q alguns ficam fora alguns dentro"*
- [x] *"resumidamente, isso q eu queria"* — com um desenho por cima da barra: a seta `<`
  abre uma **caixa** com os apps ocultos dentro (balão "apps"), e o que fica na barra é
  "fixed apps". Ou seja: painel flutuante como o do Windows, não só empurrar a barra.
  - Entregue na v1.1.0: clicar na seta abre a bandeja com os ícones que não estão na
    barra, cada um com o ícone e o nome do app; clicar num deles abre o menu daquele app.
    Precisa da permissão de Acessibilidade (é como o macOS deixa ler a barra dos outros);
    desligando a bandeja nas Preferências, o app não pede nada.
  - Os dois modos que ele pediu convivem: a bandeja (ícone dentro da caixa) e o
    empurra-barra (ícone de volta na barra), com a chave nas Preferências. Quem fica
    "fora" continua sendo decidido com ⌘ arrastando na barra.
- [x] *"usa o computer use pra ver c ta funcionando, ate agr nada"* — testado com clique
  real na seta pelo computer use: a barra expandiu e os ícones voltaram.
- [ ] Falta conferir na tela: a bandeja aberta na barra dele. O Mac ficou bloqueado a
  noite toda (`IOConsoleLocked = Yes`), e com a sessão trancada não dá para capturar tela
  nem clicar. O que deu para provar sem tela: a leitura da barra (16 ícones, 13 fora),
  o desenho da bandeja (PNG renderizado), a janela abrindo no lugar certo (topo colado
  na barra, alinhada à seta) e o acionamento de um ícone escondido devolvendo `pressed`.
