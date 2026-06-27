## 軽量化版RealAmadeus / 軽量化版リアルアマデウス

QT版リアルアマデウスのリポジトリです。

バグ修正/機能追加などの要望を、IssuesやDMにいただけたらうれしいです。

当プロジェクトはSteins;Gate 0の二次創作プロジェクトです。

NitroPlusの二次創作ガイドライン

https://www.nitroplus.co.jp/company/license/fan-fiction/

に基づいて、非営利での開発を行っています。

よって、DSUVもしくはElveltが利用者に対して金銭等の支払いを要求しないことをここに明記します。

This is the Real Amadeus (QT ver) repository.

We would appreciate it if you could send us requests for bug fixes/feature additions via Issues or DM.

This project is a fan fiction project based on Steins;Gate 0.

It is being developed non-profitably in accordance with NitroPlus' fan fiction guidelines.

https://www.nitroplus.co.jp/company/license/fan-fiction/

Therefore, we hereby state that neither DSUV nor Elvelt will request any monetary payment from users.

## How to use / 使用方法

本リポジトリをクローンし、QT 6 (6.10.1)でプロジェクトを読み込んで下さい。

### Live2Dについて

[Live2DのNativeSDK](https://www.live2d.com/sdk/download/native/) を、利用規約を許諾した上で、ダウンロードしてください。

CubismSdkForNative-X-r.X.Xを展開し、thirdparty/CubismSdkForNative-X-r.X.Xとなるように配置して下さい。

当プロジェクトでは表示フォントとしてＭＳ明朝を使用していますが、ライセンス（著作権）上の制約からフォントファイルを同梱していません。

### MS明朝フォントについて

* **Windows環境**: OS標準のＭＳ明朝を自動で検索・ロードするため、追加の準備は不要です。

* **Windows以外の環境 (Mac, Linux等)**: 起動時に自動でフォントのダウンロードが試行されます。または、お手持ちのWindows環境の `C:\Windows\Fonts\` から `msmincho.ttc`（または `msmincho.ttf`）をコピーし、`RealAmadeusPC/resources/fonts/` 配下に手動で配置していただくことでも機能します。



Clone this repository and load the project in QT 6 (6.10.1).

### About Live2D

Download the [Live2D Native SDK](https://www.live2d.com/sdk/download/native/) after agreeing to the terms of use.

Extract CubismSdkForNative-X-r.X.X and place it so that it becomes thirdparty/CubismSdkForNative-X-r.X.X.

### About MS Mincho Font
This project uses "MS Mincho" as the display font. Due to licensing and copyright restrictions, the font file is not bundled with this repository.

* **Windows environment**: The system's pre-installed "MS Mincho" is detected and loaded automatically; no extra steps are required.

* **Non-Windows environments (Mac, Linux, etc.)**: The application will automatically attempt to download the font at startup. Alternatively, you can manually copy `msmincho.ttc` (or `msmincho.ttf`) from `C:\Windows\Fonts\` of a Windows machine and place it under `RealAmadeusPC/resources/fonts/`.

## Support / サポート
RealAmadeusや、その他DSUV/ELVELTのプロジェクトを支援してくださる方がいらっしゃいましたら、寄付をしていただけると嬉しいです！
100円(0.6ドル程度)からご支援いただけます。
いただいたご支援金は、Elveltのサイト運営/サーバー維持費/プロジェクト開発費 などに使わせていただきます。

If you would like to support RealAmadeus or other DSUV/ELVELT projects, I would greatly appreciate a donation!
You can contribute starting from as little as 100 yen (approximately $0.60).
Your contributions will be used for expenses such as operating the Elvelt website, server maintenance, and project development costs.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/K6Y021XDS8)


## License / ライセンス

本プロジェクトは **CC BY-NC 4.0 (クリエイティブ・コモンズ 表示 - 非営利 4.0 国際)** の下でライセンスされています。以下の条件に従ってご利用ください：
- **改変自由**: 目的に関わらず、自由に改変・再配布が可能です。
- **商用利用禁止**: 営利目的での利用はできません。
- **クレジットの表示**: 利用の際は、適切なクレジット（改変元）を表示する必要があります。
詳細は [LICENSE](LICENSE) ファイルをご参照ください。

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0)**.
Under this license, you are free to modify and share, but you **may not use the material for commercial purposes** and **must give appropriate credit**.
Please see the [LICENSE](LICENSE) file for more details.
