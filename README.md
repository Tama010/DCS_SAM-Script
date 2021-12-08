# DCS_SAM-Script
DCSのSAMの生存性を向上させるスクリプトです。<br>
<br>

具体的には以下の機能を実装しています。<br>
・レーダーで探知したARMの着弾予想時間を算出。<br>
・着弾予想時間が一定秒数を下回るとレーダー停止。<br>
・着弾予想時間が経過するとレーダー再起動。<br>

<br>

# 使い方
1.SAM_RadarOparationLogic_verX.X.verファイルを任意の場所に保存してください。<br>
2.DCSのエディタ画面を開いてください。<br>
3.左側にある"set rules for trigger"を押下してください。<br>
4."TRIGGERS"の"NEW"ボタンを押下してください。<br>
5."TYPE"で"4 MISSION START"を選択してください。（忘れやすいので注意！）<br>
6."ACTIONS"の"NEW"ボタンを押下してください。<br>
7."ACTION:"から"DO SCRIPT FILE"を選択してください。<br>
8.1で保存したファイルを選択してください。<br>
9.SAMを配置してグループ名に"SAM"というキーワードを含めてください。（これも忘れやすいので注意！）<br>
![Test Image 6](https://github.com/Tama010/DCS_SAM-Script/blob/main/%E3%82%A8%E3%83%87%E3%82%A3%E3%82%BF%E3%83%BC%E7%94%BB%E9%9D%A2.png)
![Test Image 6](https://github.com/Tama010/DCS_SAM-Script/blob/main/%E3%82%B0%E3%83%AB%E3%83%BC%E3%83%97%E5%90%8D%E5%A4%89%E6%9B%B4.png)


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
1.3 バグ修正
　　・F-16のHTSを使用する際のバグを修正。
2.0 ロジックを抜本的に見直し。ver1は削除。
<br>
以上です。
