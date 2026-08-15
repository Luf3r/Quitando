# Fase 11 — correções da segunda revisão

## Objetivo

Fechar os três achados importantes sem alterar o domínio financeiro: conflito de pagamento preserva o comando original sem reaplicá-lo a outra sugestão; a cadeia de correções fica navegável; e todo identificador de rota aninhada é rejeitado antes de consultas sensíveis.

## Decisões

- O `409` renderiza um bloco de conflito separado do plano atual. Ele mostra origem, destino, valor e idempotency key originais como estado submetido e exige que o usuário inicie um novo report a partir da sugestão corrente.
- O histórico e o detalhe mostram cada relação direta original/substituta como link. Uma despesa pode ser simultaneamente substituta e anulada; ambos os fatos aparecem.
- Specs exercitam `group_id` inválido e ações mutáveis representativas, verificando que a rota retorna `404` sem SQL nas tabelas financeiras.

## Limites

Não há migration, mudança de fórmulas, novos estados, reversão de pagamento confirmado nem fallback. A classificação documental é comportamento de HTTP/UI; documentos normativos não mudam porque os contratos já exigem esses comportamentos.
