# DCS_SAM-Script
DCSのSAMの生存性を向上させるスクリプトです。<br>
資材リンク<br>
https://github.com/Tama010/DCS_SAM-Script/blob/main/SAM_RadarOparationLogic_ver2.0.lua
<br>

具体的には以下の機能を実装しています。<br>
・EWRと連携して射程に入るとレーダーを起動する。<br>
・対レーダーミサイルの着弾予想時間に合わせてレーダーを停止。<br>
・対空ミサイルを撃ち尽くすとレーダー停止<br>

<br>

# 基本的な使い方
1.SAM_RadarOparationLogic_verX.X.verファイルを任意の場所に保存してください。<br>
2.DCSのエディタ画面を開いてください。<br>
3.左側にある"set rules for trigger"を押下してください。<br>
4."TRIGGERS"の"NEW"ボタンを押下してください。<br>
5."TYPE"で"4 MISSION START"を選択してください。（忘れやすいので注意！）<br>
6."ACTIONS"の"NEW"ボタンを押下してください。<br>
7."ACTION:"から"DO SCRIPT FILE"を選択してください。<br>
8.1で保存したファイルを選択してください。<br>
9.SAMを配置してグループ名に"SAM"というキーワードを含めてください。（例：SA-2_SAM）<br>
10.EWRを配置してグループ名に"EWR"というキーワードを含めてください。（例：EWR1）<br>
![Test Image 6](https://github.com/Tama010/DCS_SAM-Script/blob/main/%E3%82%A8%E3%83%87%E3%82%A3%E3%82%BF%E3%83%BC%E7%94%BB%E9%9D%A2.png)
![Test Image 6](https://github.com/Tama010/DCS_SAM-Script/blob/main/%E3%82%B0%E3%83%AB%E3%83%BC%E3%83%97%E5%90%8D%E5%A4%89%E6%9B%B4.png)

# オプション機能
・射程の調整<br>
以下の対空システムのミサイル発射装置のユニット名に"SDP"というキーワードを含めるとレーダーの起動タイミングを遅らせることができます。<br>
SDPは"Shood Down Priority"の略です。<br>
<br>
・射撃強行モード<br>
追尾レーダーのユニット名に"ALRHigh"というキーワードを含めるとARMが接近しても追尾レーダーを停止させることなく射撃を強行させることができます。<br>
ALRは"Acceptable Level of Risk"の略です。<br>
<br>
・射撃強行状態のSAMを護衛するSAM<br>
射撃強行モードと組み合わせて使用します。<br>
"EscortSAM"というキーワードを含めると同一グループ内の射撃強行モードのSAMに合わせてレーダーを強制起動させることができます。<br>
SA-15などのARMの迎撃が可能なSAMに含めると効果的です。<br>

# 補足
バグや不明点、要望などがございましたらTwitterでご連絡ください。<br>
https://twitter.com/Tama010

# バージョン管理
1.0 リリース版<br>
1.1 機能追加<br>
    ・レーダー操作しないSAMの配置が可能<br>
1.2 バグ修正<br>
    ・F/A-18CでPBモードでHARMを射撃するとエラーが発生する事象を修正<br>
    ・レーダーの停止/起動のタイミングの微調整<br>
1.3 バグ修正<br>
　　・F-16のHTSを使用する際のバグを修正。<br>
2.0 ロジックを抜本的に見直し。ver1は削除。<br>
2.1 EWRの連携と弾薬有無による挙動の変化。<br>
<br>
以上です。
