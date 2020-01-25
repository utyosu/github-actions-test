#!/bin/bash

# Rubyにパスを通す
export PATH="/root/.rbenv/bin:/root/.rbenv/shims:$PATH"

# Dockerfileがマルチレイヤのとき、MySQLを起動する前に以下コマンドの実行が必要
find /var/lib/mysql -type f -exec touch {} \;

. ${SCRIPT_PATH}
