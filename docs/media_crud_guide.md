# 画像・音楽管理アプリ（Rails 8.1向け）

## 前提と確認状況

これは、すでに `rails new .` と `bundle install` が完了している、標準のRails 8.1アプリに追加するコードです。今回の授業手順で指定されたRails 8.1.3・SQLiteを想定しています。新しいRailsアプリを別に作る必要はありません。

前期のRails講義資料は検索で確認できなかったため、提示された課題文とRails公式資料を基に実装しています。授業独自の記述方法との完全な一致は未確認です。

作成側の環境にはRubyはありますがRails本体がないため、Railsを起動してのCRUD・ブラウザー動作確認は未実施です。Ruby構文・導入スクリプト・独立した範囲解析処理を確認しています。Rails用の自動テスト35件を同梱しているので、提出前に下記のテストとブラウザー確認を実施してください。

## 課題の条件と構成

- scaffold、scaffold_controller、rails generate は使用していません。
- 自分で作成するモデルは `MediaItem` の1つだけです。画像・音楽用の別モデルも追加しません。
- 1つの作品に、タイトル・作者・説明・画像・音楽を登録できます。画像だけ、音楽だけ、両方のいずれにも対応します。
- ルーティングは `resources :media_items` です。
- コントローラーの公開アクションは index / new / create / show / edit / update / destroy の7つです。
- 装飾は白背景・文字・罫線中心です。操作にJavaScriptやTurboを必須としません。

Rails標準の `ApplicationRecord` は共通の基底クラスで、独立した作品データ用モデルではありません。

## 導入方法（Codespaces）

1. `install_media_crud.rb` をダウンロードします。
2. Codespacesのファイル一覧にアップロードし、`Gemfile` と同じ階層に置きます。
3. **Codespaces内のターミナル**で、プロジェクトの一番上にいることを確認して実行します。

```bash
pwd
ls Gemfile install_media_crud.rb
ruby install_media_crud.rb
```

インストーラーは各ソースを書き出し、ルーティングを追加します。scaffoldは実行しません。Gemfile、元のREADME、元のapplicationレイアウトは変更しません。`gem "json", "< 3"` の設定はそのまま残ります。

既存ファイルの上書きやモデルの重複を検出した場合は中止します。正常に導入したあと、同じインストーラーをもう一度実行する必要はありません。

次に、次のコマンドを**1行ずつ**実行します。

```bash
bin/rails db:migrate
bin/rails test test/models/media_item_test.rb test/controllers/media_items_controller_test.rb
bin/rails server -b 0.0.0.0
```

途中でエラーが出たら、残りのコマンドは実行せず内容を確認してください。サーバーがすでに動いているターミナルでは、先に Ctrl+C で止めてください。

サーバー起動後、Codespacesの「ポート（PORTS）」で3000番をブラウザーで開きます。トップページが「作品一覧」になります。既存のroot設定があった場合は維持するので、開いたアドレスの末尾を `/media_items` にしてアクセスします。

Codespaces用の初期化ファイルで、そのCodespaceの3000番（PORT環境変数がある場合はその番号）だけを許可ホストに追加します。サーバーのホスト制限全体を無効にはしません。

ポートを公開にする必要はありません。本アプリにはログイン・ユーザー別のアクセス制御がないため、学習時は非公開のCodespaceポートで使用してください。

## 入力項目と保存先

| 入力項目 | DB項目 | 備考 |
| --- | --- | --- |
| タイトル | title (string) | 必須・100文字以内 |
| 作者・アーティスト | creator (string) | 必須・100文字以内 |
| 説明 | description (text) | 任意・2000文字以内 |
| 画像 | image_name / image_content_type / image_data | 名前・種類・ファイル本体 |
| 音楽 | music_name / music_content_type / music_data | 名前・種類・ファイル本体 |

`id`・`created_at`・`updated_at` を除いて9つのDB項目があります。ファイルのフォーム入力名 `image_upload` / `music_upload` は一時的な属性で、保存時に名前・種類・本体の3項目に分けます。

画像はPNG・JPEG・GIF・WebP（5MB以下）、音楽はMP3・WAV（10MB以下）を受け付けます。この資料でのMBは1024×1024バイトとして実装しています。空ファイルは登録できません。

画像・音楽の本体は `media_items` テーブルのbinary列に保存します。モデルを1つに保つことを優先した小規模課題向けの方式です。大容量・多数のファイルを配信する本番サービス向けの構成ではありません。ファイル形式判定はRailsに付属する依存ライブラリMarcelを使い、拡張子だけでは判定しません。ただし、全ファイルを完全にデコードして破損検査する仕組みではありません。

## 7機能とルーティング

`config/routes.rb` のRails.application.routes.drawブロック内に、次の記述が入ります。

```ruby
resources :media_items
root "media_items#index"
```

| HTTPメソッド | URL | アクション | 処理 |
| --- | --- | --- | --- |
| GET | /media_items | index | 一覧表示 |
| GET | /media_items/new | new | 新規登録画面 |
| POST | /media_items | create | DBへの登録 |
| GET | /media_items/:id | show | 詳細表示 |
| GET | /media_items/:id/edit | edit | 編集画面 |
| PATCH / PUT | /media_items/:id | update | DBの更新 |
| DELETE | /media_items/:id | destroy | DBから削除 |

ルーティングを自分で確認するコマンドは、次のとおりです。

```bash
bin/rails routes -c media_items
```

updateにはPATCHとPUTの2種類があるため、表示される行数とアクションの個数は一致しないことがあります。

画像本体は `/media_items/:id?file=image`、音楽本体は `/media_items/:id?file=music` から返します。どちらもshowアクション内で処理するので、画像配信用や音楽配信用の追加アクションは作っていません。音楽プレーヤーの範囲要求に対応する処理はprivateメソッドです。

## ソースの場所と役割

| ファイル | 役割 |
| --- | --- |
| app/models/media_item.rb | 入力チェック、ファイルの種類・容量確認、保存用データの組み立て |
| app/controllers/media_items_controller.rb | 7つのCRUDアクションと、許可する入力項目の指定 |
| app/views/media_items/index.html.erb | 一覧画面 |
| app/views/media_items/new.html.erb | 新規登録画面 |
| app/views/media_items/show.html.erb | 詳細画面、画像表示、音楽再生、削除 |
| app/views/media_items/edit.html.erb | 編集画面 |
| app/views/media_items/_form.html.erb | 新規・編集で共用する入力フォーム |
| app/views/layouts/media_crud.html.erb | 共通の画面枠 |
| app/assets/stylesheets/media_crud.css | 最小限の装飾 |
| db/migrate/日時_create_media_items.rb | 作品用テーブルと列の作成 |
| config/locales/media_crud.*.yml | 項目名の日本語表示 |
| config/initializers/media_crud_codespaces.rb | Codespaces開発時の許可ホスト設定 |
| test/models/media_item_test.rb | モデルのテスト15件 |
| test/controllers/media_items_controller_test.rb | ルーティング・HTTP操作のテスト20件 |

処理の流れは、フォーム → resourcesのルーティング → コントローラー → モデル → DB → 詳細画面への移動、です。登録・更新の失敗時はエラーを表示し、保存しません。

create/updateでは、Strong Parametersの `params.expect` で許可した項目だけを受け取ります。ファイル本体やContent-Typeをリクエストから直接書き換えられるようにはしていません。

削除は詳細画面の「この作品を削除する」を開いてから「削除を確定する」で実行します。HTML標準のdetails要素とbutton_toを使うため、JavaScriptがなくても動く構成です。

## ブラウザーでの動作確認

1. 「新規登録」を開き、タイトルと作者を入力します。
2. 画像と音楽を選んで「登録する」を押します。同梱ZIPの `samples/sample.png` と `samples/sample.wav` を使えます。
3. 詳細画面で画像が表示され、再生ボタンで音が鳴ることを確認します。
4. 「一覧に戻る」で作品が一覧に追加されていることを確認します。
5. 「編集」でタイトル・説明を変えて「更新する」を押し、変更が反映されることを確認します。ファイルを選び直さなければ元のファイルを保持します。
6. ファイルを選び直して更新し、差し替えも確認します。
7. 詳細画面で「この作品を削除する」→「削除を確定する」を押し、一覧から消えることを確認します。

入力エラー後は新しいアップロードファイルを選び直します。すでにDBに保存してある元のファイルは、失敗した更新では変更されません。

同梱サンプルは動作確認用に作成した小さな市松模様のPNGと短い合成音WAVです。自分の画像・音楽を使っても構いません。

## GitHubへの保存

ブラウザー確認後、サーバーをCtrl+Cで止めるか、別のターミナルを開いて実行します。

```bash
git status
git add -A
git commit -m "Add image and music CRUD app"
git push
```

git statusで提出と無関係なファイルがないことを確認してください。標準のRails設定ではDBファイルはGit管理対象外なので、登録した作品データ自体をGitHubへバックアップする手順ではありません。提出先での再現はマイグレーション実行後に新しく登録します。

## エラーが出たとき

`No such file or directory -- install_media_crud.rb` は、ファイルの置き場所かターミナルの現在位置を確認します。ファイルはGemfileと同じ階層です。

`PendingMigrationError` が出た場合は、サーバーを止めて `bin/rails db:migrate` を実行します。

インストーラーが「すでにモデルがあります」で止まった場合は、導入済みか、別のモデルがある状態です。既存コードを消して解決せず、まずファイル一覧を確認してください。

ポート3000が使用中の場合は、すでに起動中のRailsサーバーを確認してください。

テストに失敗した場合は、その失敗出力を確認してから提出してください。この資料は未実行のテストを「成功済み」とは扱っていません。

## 参照した公開資料

前期講義資料の代わりではなく、実装APIを確認するための公開資料です。

- Rails Routing from the Outside In（resourcesと7アクション）: https://guides.rubyonrails.org/routing.html
- Action View Form Helpers（form_withとfile_field）: https://guides.rubyonrails.org/form_helpers.html
- Action Controller Overview（Strong Parametersとparams.expect）: https://guides.rubyonrails.org/action_controller_overview.html
- Active Record Validations（入力検証）: https://guides.rubyonrails.org/active_record_validations.html
- Active Record Migrations（DBテーブル作成）: https://guides.rubyonrails.org/active_record_migrations.html
- ActionController::DataStreaming（send_data）: https://api.rubyonrails.org/classes/ActionController/DataStreaming.html
- Marcel（ファイル内容からのMIME判定）: https://github.com/rails/marcel
- Testing Rails Applications（テストの実行）: https://guides.rubyonrails.org/testing.html
- GitHub Docs（Codespacesのポート）: https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace

- GitHub Docs（Codespacesの環境変数）: https://docs.github.com/en/codespaces/developing-in-a-codespace/default-environment-variables-for-your-codespace
