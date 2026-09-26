# Capturas reais do produto

As imagens dashboard-summary são capturas do Resumo atual, com o cenário fictício Casa da Vila (Ana, Bruno e Carla), criado por serviços reais em spec/system/landing_capture_spec.rb. Não são mockups.

Para renovar após alterações visuais:

1. Execute `CAPTURE_LANDING=true bundle exec rspec spec/system/landing_capture_spec.rb` no ambiente de testes com Chromium.
2. Os PNGs claros e escuros são escritos em `tmp/polish/dashboard-{light,dark}-{desktop,mobile}.png`, respectivamente 1440x1257 e 480x1407. O cenário usa o tema claro e o escuro e salva uma captura de cada tamanho.
3. `docker compose run --rm web bundle exec ruby script/export_landing_captures.rb` recorta a captura no Resumo, exporta WebP responsivos (`1440x1080`, `720x540` e `464x1285`; o corte móvel remove a barra de rolagem do Chromium) com `Q: 88` e cria favicon 16/32/48 px e ícone Apple de 180 px a partir do recorte opaco da logo.
4. Confira visualmente as quatro capturas e mantenha os atributos width/height do picture sincronizados com as dimensões reais. Esta operação redimensiona pixels, não valores monetários.

A fotografia fornecida pelo usuário foi integrada a partir de `hero-friends-source.jpg` (1376x768, proporção próxima a 16:9). As variantes WebP são recortadas para 16:9 e servem o hero em 480x270, 768x432 e 1024x576; `hero-friends-og.webp` é 1200x630 para Open Graph. A foto mostra um grupo reunido à mesa e substitui a fotografia anterior.

Para renovar as variantes com ruby-vips, use a fonte original e preserve as dimensões declaradas no `picture` e no metadata Open Graph. Verifique o resultado visualmente após o recorte e mantenha a imagem da landing como fotografia real, sem recriar a interface do app.
