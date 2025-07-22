# SSL証明書セットアップガイド

## CA証明書の生成方法

このTerraformモジュールは、Squidプロキシのssl_bump機能で使用するCA証明書を自動生成します。EC2インスタンスのuser-dataスクリプトが自動的にCA証明書を生成しますが、手動で生成する場合は以下のコマンドを使用してください。

### 1. CA秘密鍵の生成

```bash
openssl genrsa -out squid-ca-key.pem 4096
```

### 2. CA証明書の生成

```bash
openssl req -new -x509 -days 3650 -key squid-ca-key.pem -out squid-ca-cert.pem -subj "/C=JP/ST=Tokyo/L=Tokyo/O=TLS-Decrypt/OU=Security/CN=Squid-CA"
```

### 3. 証明書の配置

```bash
sudo mkdir -p /etc/squid/ssl_cert
sudo mv squid-ca-key.pem /etc/squid/ssl_cert/
sudo mv squid-ca-cert.pem /etc/squid/ssl_cert/
sudo chown squid:squid /etc/squid/ssl_cert/squid-ca-*
sudo chmod 400 /etc/squid/ssl_cert/squid-ca-key.pem
sudo chmod 444 /etc/squid/ssl_cert/squid-ca-cert.pem
```

## クライアント側の設定

### 1. CA証明書の取得

EC2インスタンスが起動後、以下のコマンドでCA証明書を取得できます：

```bash
# EC2インスタンスにSSH接続後
sudo cat /etc/squid/ssl_cert/squid-ca-cert.pem
```

### 2. モバイルデバイスへの証明書インストール

#### iOS
1. CA証明書ファイル（.pem）をメールで送信するか、Webサーバー経由でダウンロード
2. 設定 > 一般 > VPNとデバイス管理 > プロファイルをインストール
3. 設定 > 一般 > 情報 > 証明書信頼設定 で該当証明書を信頼済みに設定

#### Android
1. 設定 > セキュリティ > 暗号化と認証情報 > 証明書をインストール
2. CA証明書ファイルを選択してインストール

## VPN Client設定用証明書の生成（Client VPN用）

AWS Client VPNで使用するクライアント証明書の生成：

### 1. クライアント秘密鍵の生成

```bash
openssl genrsa -out client.key 4096
```

### 2. クライアント証明書署名要求の生成

```bash
openssl req -new -key client.key -out client.csr -subj "/C=JP/ST=Tokyo/L=Tokyo/O=TLS-Decrypt/OU=Client/CN=client"
```

### 3. クライアント証明書の生成

```bash
openssl x509 -req -in client.csr -CA squid-ca-cert.pem -CAkey squid-ca-key.pem -CAcreateserial -out client.crt -days 365
```

### 4. OpenVPN設定ファイルへの組み込み

生成された`client.crt`と`client.key`をAWS Client VPNの設定ファイルに組み込みます。

## セキュリティ注意事項

- CA秘密鍵は厳重に管理し、不要なアクセスを防ぐため適切な権限設定を行ってください
- 本番環境では、より強固な証明書管理システムの使用を検討してください
- 定期的な証明書の更新を実施してください
- 証明書の有効期限を監視してください

## トラブルシューティング

### Squidが起動しない場合
1. 証明書ファイルの権限確認：`ls -la /etc/squid/ssl_cert/`
2. Squidログの確認：`sudo journalctl -u squid -f`
3. SSL証明書データベースの確認：`ls -la /var/lib/squid/ssl_db/`

### SSL接続エラーが発生する場合
1. CA証明書がクライアントデバイスに正しくインストールされているか確認
2. 証明書の有効期限を確認
3. Squidアクセスログを確認：`sudo tail -f /var/log/squid/access.log`