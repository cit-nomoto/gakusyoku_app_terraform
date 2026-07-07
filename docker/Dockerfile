# --- Litestream ビルドステージ ---
FROM python:3.12-slim AS litestream-builder

ENV LITESTREAM_VERSION=v0.3.13

RUN apt-get update && apt-get install -y --no-install-recommends wget \
    && wget -q -O /tmp/litestream.tar.gz \
       https://github.com/benbjohnson/litestream/releases/download/${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-amd64.tar.gz \
    && tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz \
    && rm /tmp/litestream.tar.gz

# --- 本番イメージ ---
FROM python:3.12-slim
WORKDIR /app

# 日本語フォント (matplotlib のグラフ描画で使用)
# アプリ側は Windows のフォント名 (MS Gothic 等) を指定するため、
# Noto Sans CJK JP のファミリー名を「MS Gothic」に書き換えた複製を配置し、
# アプリのコードを変更せずに日本語を描画できるようにする
RUN apt-get update && apt-get install -y --no-install-recommends fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir fonttools \
    && mkdir -p /usr/local/share/fonts \
    && python -c "\
import glob; \
from fontTools.ttLib import TTCollection; \
path = glob.glob('/usr/share/fonts/**/NotoSansCJK-Regular.ttc', recursive=True)[0]; \
fonts = TTCollection(path).fonts; \
jp = [f for f in fonts if (f['name'].getDebugName(16) or f['name'].getDebugName(1)) == 'Noto Sans CJK JP'][0]; \
name = jp['name']; \
name.names = [r for r in name.names if r.nameID not in (1, 3, 4, 6, 16, 17)]; \
[name.setName('MS Gothic', i, 3, 1, 0x409) for i in (1, 3, 4, 16)]; \
name.setName('MSGothic', 6, 3, 1, 0x409); \
jp.save('/usr/local/share/fonts/msgothic-compat.otf')" \
    && pip uninstall -y fonttools

# 依存パッケージをインストール
COPY gakusyoku_app/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションのソースをコピー
COPY gakusyoku_app/ ./

# Litestream CLI をコピー
COPY --from=litestream-builder /usr/local/bin/litestream /usr/local/bin/litestream

# litestream の設定ファイルと起動スクリプトをコピー
COPY docker/litestream.yml /etc/litestream.yml
COPY docker/run.sh ./
RUN chmod +x run.sh

# Cloud Run はポート 8080 を使用する
EXPOSE 8080

# 起動スクリプトを実行する
CMD ["/app/run.sh"]