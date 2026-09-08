CREATE TABLE IF NOT EXISTS controle_acesso_importacao (
    evento_id VARCHAR(80) NOT NULL,
    dispositivo_id VARCHAR(80) NOT NULL,
    tagid VARCHAR(20) NOT NULL,
    acesso DATETIME NOT NULL,
    liberacao BOOLEAN NOT NULL,
    recebido_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status ENUM('PROCESSADO', 'REJEITADO') NOT NULL,
    motivo_rejeicao VARCHAR(255) NULL,
    PRIMARY KEY (evento_id),
    KEY idx_importacao_dispositivo_acesso (dispositivo_id, acesso)
);