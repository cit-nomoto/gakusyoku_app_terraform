#!/bin/sh

set -e

# instance ディレクトリを作成する (SQLite のデータベースファイルの保存先)
mkdir -p /app/instance

#gunicornのinstall
pip install 'gunicorn>=20.1'

# Google Cloud Storage からデータベースファイルを復元する
# `-if-replica-exists` フラグを指定すると、レプリカが存在する場合にのみ復元を行う
# レプリカがあれば復元する（同一デプロイ内の再起動をまたいでデータを保持）。
# レプリカが無ければ source.zip 同梱の instance/app.db をシードデータとして
# そのまま使う（同梱 DB も無ければアプリが新規作成する）。
# デプロイ時は Cloud Build がレプリカを削除するため（→ cloudbuild.tf Step 5）、
# source.zip をアップロードするたびに DB は zip の中身にリセットされる。
# restore は出力先にファイルが存在すると失敗するため、一時パスに復元してから移す
litestream restore -if-replica-exists -config /etc/litestream.yml \
  -o /tmp/restored.db /app/instance/app.db
if [ -f /tmp/restored.db ]; then
  mv /tmp/restored.db /app/instance/app.db
fi

# Google Cloud Storage にデータベースファイルをレプリケートしながら Gunicorn でアプリを起動する
litestream replicate -config /etc/litestream.yml \
  -exec "gunicorn --bind 0.0.0.0:8080 --workers 1 main:create_app"
