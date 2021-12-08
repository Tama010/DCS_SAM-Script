function SAMDefenceAgainstARMLogic()
	local obj = {}
	local _designatedGroupList = {}
	local _designatedGroupListExecuteFlag = {}
	local _RECURSIVEPROCESSINGTIME = 5
	
	
	local _stopOparationCounter = 1
	local _stopOparationList = {}
	local _restartOparationCounter = 1
	local _restartOparationQueue = 1
	local _restartOparationList = {}
	
	RadarObj = {}
	RadarObj.new = function(_designatedGrp, _designatedGropuListExecuteFlagArrayNum, _stoppingTime)
			local _radarObj = {}
			_radarObj._designatedGrp = _designatedGrp
			_radarObj._designatedGropuListExecuteFlagArrayNum = _designatedGropuListExecuteFlagArrayNum
			_radarObj._stoppingTime = _stoppingTime
			_radarObj.getGrpObj = function(self)
						local _grpObj = _designatedGrp
					return _grpObj
				end
			_radarObj.getArrayNum = function(self)
					return _designatedGropuListExecuteFlagArrayNum
				end
			return _radarObj
		end
	
	-- 最初に呼んで初期化する
	function obj:init()
		
		local _allGroupList = getAllGroups() -- 全てのグループを取得
		_designatedGroupList = fillterGroupList(_allGroupList)
		
		-- ariDefenceが実行されても動かないようにする
		for i = 1, #_designatedGroupList do
			_designatedGroupListExecuteFlag[i] = true
		end
		
		initComment() -- デバッグ用
	end
	
	-- 読み込み確認デバッグ用コメント
	function initComment()
		--trigger.action.outText("以下のグループがSAM強化スクリプトの対象です。", 5) -- デバッグ用
		for i = 1, #_designatedGroupList do
			local _gpObj = _designatedGroupList[i]
			--trigger.action.outText("    " .. string.format(Group.getName(_gpObj)), 5) -- デバッグ用
		end
		
	end
	
	-- ゲーム中実行され続けるメインの処理
	function obj:airDefence()
		
		--trigger.action.outText("レーダー起動中の対象グループ", 3)
		
		--for i, _designatedGrp in pairs(_designatedGroupList) do
		for _designatedGroupListExecuteFlagArrayNum = 1, #_designatedGroupList do
			local _designatedGrp = _designatedGroupList[_designatedGroupListExecuteFlagArrayNum]
			
			-- チェック
			local _executeFlag = commonValidate(_designatedGrp, _designatedGroupListExecuteFlagArrayNum)
			
			if _executeFlag then
				--trigger.action.outText("    グループ名：" .. string.format(Group.getName(_designatedGrp)), 3)  -- デバッグ用
				executeEnhancedAirDeffence(_designatedGrp, _designatedGroupListExecuteFlagArrayNum)
			end
		end
		
		adjustRestartListTime()
		
		-- 回帰処理
		timer.scheduleFunction(self.airDefence, self, timer.getTime() + _RECURSIVEPROCESSINGTIME) 
		
	end
	
	-- 準備
	-- 全てのグループを取得
	function getAllGroups()

		local _initialAllGroupList = {}
		
		-- 中立グループを全て取得
		for i, gp in pairs(coalition.getGroups(0)) do
			table.insert(_initialAllGroupList, gp)
		end

		-- Redグループを全て取得
		for i, gp in pairs(coalition.getGroups(1)) do
			table.insert(_initialAllGroupList, gp)
		end
		
		-- Blueグループを全て取得
		for i, gp in pairs(coalition.getGroups(2)) do
			table.insert(_initialAllGroupList, gp)
		end
		
		return _initialAllGroupList
	end

	-- 対象を抽出
	function fillterGroupList(_groupListAll)
		local _keyWord = "SAM" -- グループ名に含まれるキーワード
		local _list = {}
		
		for i = 1, #_groupListAll do
			local _gpObj = _groupListAll[i]
			if string.find(_gpObj:getName(), _keyWord) then
				table.insert(_list, _gpObj)
			end
		end
		return _list
	end

	-- 処理開始バリデーションチェック
	function commonValidate(_gpObj, _num)
			
			if _designatedGroupListExecuteFlag[_num] == false then
				return false
			end
			
			-- 存在チェック
			if Group.isExist(_gpObj) == false then
				return false
			end
		
		return true
	end
	
	-- 強化された防空
	function executeEnhancedAirDeffence(_designatedGrp, _designatedGroupListExecuteFlagArrayNum)
		local _targetList

		-- 探知
		local _detectedTargetList = detecte(_designatedGrp)
		
		-- 識別
		if #_detectedTargetList >0 then
			_targetList = identify(_detectedTargetList)
		else
			return nil
		end
		
		-- 判断
		local _radarOparationFlag = false
		local _stoppingTime
		if #_targetList > 0 then
			_radarOparationFlag, _stoppingTime = judge(_designatedGrp, _targetList)
		end
		
		-- 操作
		if _radarOparationFlag then
			oparation(_designatedGrp, _stoppingTime, _designatedGroupListExecuteFlagArrayNum)
			
		end
	end
	
	-- 探知
	function detecte(_designatedGrp)
		local _detectedTargetList
		local _flag = false
		
		local _gpController = Group.getController(_designatedGrp)
		
		_detectedTargetList = _gpController:getDetectedTargets(Controller.Detection.RADAR)
		
		return _detectedTargetList
		
	end

	-- 識別
	function identify(_detectedTargetList)
		local _armList = {}
		
		--trigger.action.outText("        探知中：", 3)  -- デバッグ用
		
		for _, _target in pairs( _detectedTargetList ) do
			local _obj = _target.object
			if _obj ~= nil then
				if identifyARMorNot(_obj) then
					table.insert(_armList, _obj)
				end
			end
		end
		
		return _armList
	end
	
	-- ARMか判別
	function identifyARMorNot(_obj)
		local armList = {}
		if _obj:getCategory() ==  Object.Category.WEAPON then
			_targetName = _obj:getTypeName()
			if _targetName == "AGM_88" 
				or _targetName == "X_31P" 
				or _targetName == "X_25MP"  
				or _targetName == "LD-10" then
				
				return true
			end
		end
		--trigger.action.outText("                航空機", 3) -- デバッグ用
		return false
	end
	
	-- 判断
	function judge(_designatedGrp, _targetList)
		
		local _timeList = {}
		local _stoppingTime = 20
		local _flag = false
		local _randomTime = 0
		local _finalStoppingTime = 0
		
		for i = 1, #_targetList do
			local _armObj = _targetList[i]

			
			if isHot(_armObj, _designatedGrp) then
				local _time = impactTime(_armObj, _designatedGrp)
				--trigger.action.outText("                "..string.format("ARM探知  " .."着弾推定時間：" .. math.ceil(_time) .. "秒"), 3) -- デバッグ用
				table.insert(_timeList, _time)
				if _time < 40 then
					_flag = true
				end
			end
		end
		
		-- 時間チェック
		if _flag then
			table.sort(_timeList)
			for i = 1, #_timeList do
				if _timeList[i] > _stoppingTime and _stoppingTime < _timeList[i] + 60 then
					_stoppingTime = _timeList[i]
				end
			end
			-- バッファー
			_randomTime = math.random(10,15)
			
			
			--trigger.action.outText("                        レーダー停止処理開始", 3) -- デバッグ用
			--trigger.action.outText("                        " .. math.ceil(_stoppingTime + _randomTime).."秒後に再起動" , 3) -- デバッグ用
		end

		return _flag, _stoppingTime + _randomTime
	end

	-- 接近しているか分析
	function isHot(_armObj, _designatedGrp)
		
		local _samPosition = _designatedGrp:getUnits()[1]:getPoint()
		local _armPosition = _armObj:getPoint()
		_armVelocity = _armObj:getVelocity()	
		
		_hotXFlag = false

		if _armVelocity.x >=0 then
			if _armPosition.x < _samPosition.x then
				_hotXFlag = true
			end
		else
			if _armPosition.x > _samPosition.x then
				_hotXFlag = true
			end
		end
		
		if _hotXFlag then
			if _armVelocity.z >=0 then
				if _armPosition.z < _samPosition.z then
					return true
				end
			else
				if _armPosition.z > _samPosition.z then
					return true
				end
			end
			
			return false
		end

		return false
	end
	
	-- 着弾予想時間算出
	function impactTime(_armObj, _designatedGrp)
		
		-- 距離取得
		local _distance = getDistance(_armObj, _designatedGrp)
		--trigger.action.outText( "    Threat distance : "..string.format("%7.1f", _distance).."m", 3)
		
		-- 飛翔速度取得
		local _speed = getTargetSpeed(_armObj)
		--trigger.action.outText( "    Threat speed : "..string.format("%7.1f", _speed).."km/h", 3)
		
		-- 高度取得
		local _alt = _armObj:getPoint().y
		--trigger.action.outText( "    Threat altitude : "..string.format("%7.1f", _alt).."m", 3)
		
		-- 着弾予想時間算出
		local _time = culculateTime(_distance, _speed, _alt)
		--trigger.action.outText( "    着弾予想時間 : "..string.format("%7.1f", _time).."s", 3)
		
		return _time
		
	end
	
	-- SAMとターゲットの距離を取得
	function getDistance(_armObj, _designatedGrp)
		
		local _samPosition = _designatedGrp:getUnits()[1]:getPoint()
		local _armPosition = _armObj:getPoint()
		
		local _distance = math.sqrt((_samPosition.x - _armPosition.x)^2 + (_samPosition.y - _armPosition.y)^2 + (_samPosition.z - _armPosition.z)^2)
		return _distance
	end
	
	-- ターゲットの飛翔速度を取得（2次元：X軸Z軸）
	function getTargetSpeed(_armObj)
		
		local _targetVelocityInfo = _armObj:getVelocity()
		local _targetSpeed = math.sqrt(_targetVelocityInfo.x^2 + _targetVelocityInfo.z^2)
		return _targetSpeed
	end
	
	-- 着弾予想時間算出ロジック
	function culculateTime(_distance, _speed, _alt)
		
		-- 距離から補正値算出（これは感覚）
		--local _correctionDistanceValue = 0.00018 * (math.ceil(_distance/1000))^2
		local _correctionDistanceValue = 0.00009 * (_distance/1000)^2
		--trigger.action.outText( "    距離補正値 : "..string.format(_correctionDistanceValue).."", 3)
		--local _correctionAltValue = 0.32/ ( math.ceil(_alt) / 10000 + 1) - 0.09
		local _correctionAltValue = 0.32/ ( math.ceil(_alt) / 10000 + 1) - 0.09 - 0.0001 * _distance/1000
		--trigger.action.outText( "    高度補正値 : "..string.format(_correctionAltValue).."", 3)
		
		_correctionSum = _correctionDistanceValue + _correctionAltValue
		--trigger.action.outText( "    合計補正値 : "..string.format(_correctionSum).."", 3)
		_correctionDistance = _distance + _distance * _correctionSum

		return _correctionDistance / _speed
		
	end
	
	-- 操作
	function oparation(_designatedGrp, _stoppingTime, _designatedGroupListExecuteFlagArrayNum)
		
		-- レーダー停止
		executeStopRadarEmission(_designatedGrp, _designatedGroupListExecuteFlagArrayNum, _stoppingTime)
		
		-- レーダー再起動
		executeRestartRadarEmission(_designatedGrp, _designatedGroupListExecuteFlagArrayNum, _stoppingTime)
		
	end
	
	-- レーダー停止処理
	function executeStopRadarEmission(_designatedGrp, _designatedGroupListExecuteFlagArrayNum, _stoppingTime)
		
		table.insert(_stopOparationList, RadarObj.new(_designatedGrp, _designatedGroupListExecuteFlagArrayNum, nil)) 
		_designatedGroupListExecuteFlag[_designatedGroupListExecuteFlagArrayNum] = false
		timer.scheduleFunction(stopRadarEmission , {}, timer.getTime() + 3)
	end
	
	-- レーダー停止
	function stopRadarEmission()
		
		local _stopOparationObj = _stopOparationList[_stopOparationCounter]
		
		if Group.isExist(_stopOparationObj.getGrpObj()) then
			_stopOparationObj.getGrpObj():enableEmission(false)
			end
		_stopOparationCounter = _stopOparationCounter + 1
		
		
	end
	
	-- レーダー再起動処理
	function executeRestartRadarEmission(_designatedGrp, _designatedGroupListExecuteFlagArrayNum, _stoppingTime)
		
		table.insert(_restartOparationList, RadarObj.new(_designatedGrp, _designatedGroupListExecuteFlagArrayNum, _stoppingTime + _RECURSIVEPROCESSINGTIME)) 
		sortRestartList()
		timer.scheduleFunction(restartRadarEmission , {}, timer.getTime() + _stoppingTime)
	end

	-- 再起動時間リスト内のオブジェクト操作（時間を引く）
	function adjustRestartListTime()
		for i = 1, #_restartOparationList do
			if _restartOparationList[i]._stoppingTime >= 0 then
				local _time = _restartOparationList[i]._stoppingTime - _RECURSIVEPROCESSINGTIME
				_restartOparationList[i]._stoppingTime = _time
			end
		end
	end
	
	-- 時間順に並び替え
	function sortRestartList() 
		table.sort(_restartOparationList, function(a,b) return a._stoppingTime < b._stoppingTime end)
	end
	
	-- レーダー再起動
	function restartRadarEmission()
		--trigger.action.outText("    ".._restartOparationList[_restartOparationCounter].getGrpObj():getName() .. "のレーダーが再起動", 3)
		local _restartOparationObj = _restartOparationList[_restartOparationCounter]
		if Group.isExist(_restartOparationObj.getGrpObj()) then
			_restartOparationObj.getGrpObj():enableEmission(true)
		end
		_restartOparationCounter = _restartOparationCounter + 1
		
		_designatedGroupListExecuteFlag[_restartOparationObj._designatedGropuListExecuteFlagArrayNum] = true
	end

	return obj
end

local _instance = SAMDefenceAgainstARMLogic() -- インスタンス生成

_instance:init() -- 初期化開始
_instance:airDefence() -- 具体的な処理を開始