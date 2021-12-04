# DCS_SAM-Script
DCSのSAMの生存性を向上させるスクリプトです。<br>
以下のサイトに記載されたコードをベースに改良しました。<br>
https://forums.eagle.ru/topic/96493-smarter-sam<br><br>
具体的には以下の機能を実装しています。<br>
・対レーダーミサイル（以下ARM）の発射を検知するとレーダーを停止。<br>
・一定時間経過するとレーダーを再起動。<br>
・ARMの発射地点からの距離の応じてレーダー停止のタイミングと再起動のタイミングは変化。<br>
<br>
★注意<br>
F/A-18CからPBモードでHARMを発射するとレーダー操作されません。<br>
<br>

# 使い方
1.SAM_AgainstSEADLogic_verXX.luaファイルを任意の場所に保存してください。<br>
2.DCSのエディタ画面を開いてください。<br>
3.左側にある"set rules for trigger"を押下してください。<br>
4."TRIGGERS"の"NEW"ボタンを押下してください。<br>
5."ACTIONS"の"NEW"ボタンを押下してください。<br>
6."ACTION:"から"DO SCRIPT FILE"を選択してください。<br>
7.1で保存したファイルを選択してください。<br>
<br>
あとはSAMを配置したりして戦ってみてください。<br>
# 補足
レーダーを出すユニット（SR、TR）のUnitNameに"RadarAlwaysActivated"というキーワードを含めるとレーダーを停止しなくなります。

# バージョン管理
1.0 リリース版<br>
1.1 機能追加<br>
      ・レーダー操作しないSAMの配置が可能<br>
1.2 バグ修正<br>
      ・F/A-18CでPBモードでHARMを射撃するとエラーが発生する事象を修正<br>
      ・レーダーの停止/起動のタイミングの微調整<br>
<br>
以上です。
