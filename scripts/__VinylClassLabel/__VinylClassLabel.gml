/// @param name
/// @param parent
/// @param adHoc

function __VinylClassLabel(_name, _parent, _adHoc) constructor
{
    static __idToInstanceDict = __VinylGlobalData().__idToInstanceDict;
    
    __name   = _name;
    __parent = _parent;
    __adHoc  = _adHoc;
    
    
    
    static toString = function()
    {
        return "<label " + __name + ">";
    }
    
    #region Initialize
    
    static __Initialize = function(_labelData = {}, _knobDict)
    {
        //Unpack the definition data
        var _gain            = _labelData[$ "gain"               ] ?? (VINYL_CONFIG_DECIBEL_GAIN? 0 : 1);
        var _pitch           = _labelData[$ "pitch"              ] ?? (VINYL_CONFIG_PERCENTAGE_PITCH? 100 : 1);
        var _loop            = _labelData[$ "loop"               ] ?? undefined;
        var _limit           = _labelData[$ "limit"              ];
        var _limitFadeOut    = _labelData[$ "limit fade out rate"] ?? VINYL_DEFAULT_GAIN_RATE;
        var _tagArray        = _labelData[$ "tag"                ] ?? _labelData[$ "tags"];
        var _effectChainName = _labelData[$ "effect chain"       ];
        
        if (VINYL_CONFIG_DECIBEL_GAIN) _gain = __VinylGainToAmplitude(_gain);
        if (VINYL_CONFIG_PERCENTAGE_PITCH) _pitch /= 100;
        
        
        
        //Sort out the gain
        __configGainKnob = false;
        
        if (is_string(_gain))
        {
            if (string_char_at(_gain, 1) == "@")
            {
                var _knobName = string_delete(_gain, 1, 1);
                var _knob = _knobDict[$ _knobName];
                if (!is_struct(_knob)) __VinylError("Error in ", self, " for gain property\nKnob \"", _knobName, "\" doesn't exist");
                
                _knob.__TargetCreate(self, "gain");
                _gain = _knob.__actualValue; //Set gain to the current value of the knob
                
                __configGainKnob = true;
            }
            else
            {
                __VinylError("Error in ", self, "\nGain must be a number or a knob name");
            }
        }
        else if (!is_numeric(_gain))
        {
            __VinylError("Error in ", self, "\nGain must be a number or a knob name");
        }
        
        __configGain = _gain;
        
        
        
        //Sort out the pitch
        __configPitchKnob = false;
        
        if (is_string(_pitch))
        {
            if (string_char_at(_pitch, 1) == "@")
            {
                var _knobName = string_delete(_pitch, 1, 1);
                var _knob = _knobDict[$ _knobName];
                if (!is_struct(_knob)) __VinylError("Error in ", self, " for pitch property\nKnob \"", _knobName, "\" doesn't exist");
                
                _knob.__TargetCreate(self, "pitch");
                __configPitchLo = _knob.__actualValue; //Set pitch to the current value of the knob
                __configPitchHi = __configPitchLo;
                
                __configPitchKnob = true;
            }
            else
            {
                __VinylError("Error in label ", self, "\nPitch must be either a number greater than zero, a two-element array, or a knob name");
            }
        }
        else if (is_numeric(_pitch) && (_pitch > 0))
        {
            __configPitchLo = _pitch;
            __configPitchHi = _pitch;
        }
        else if (is_array(_pitch))
        {
            if (array_length(_pitch) != 2) __VinylError("Error in ", self, "\nPitch array must have exactly two elements (length=", array_length(_pitch), ")");
            
            __configPitchLo = _pitch[0];
            __configPitchHi = _pitch[1];
            
            if (__configPitchLo > __configPitchHi)
            {
                __VinylTrace("Warning! Error in ", self, ". Low pitch (", __configPitchLo, ") is greater than high pitch (", __configPitchHi, ")");
                var _temp = __configPitchLo;
                __configPitchLo = __configPitchHi;
                __configPitchHi = _temp;
            }
        }
        else
        {
            __VinylError("Error in ", self, "\nPitch must be either a number greater than zero, a two-element array, or a knob name");
        }
        
        
        
        //Sort out the loop state
        if (!is_bool(_loop) && !is_undefined(_loop)) __VinylError("Error in ", self, "\nLoop behaviour must be a boolean (<true> or <false>)");
        __configLoop = _loop;
        
        
        
        if (!is_undefined(_limit) && (!is_numeric(_limit) || (_limit <= 0))) __VinylError("Error in ", self, "\nInstance limit must be a number greater than zero");
        __limitMaxCount = _limit;
        
        if (!is_numeric(_limitFadeOut) || (_limitFadeOut <= 0)) __VinylError("Error in ", self, "\nLimit-related fade in rate must be a number greater than zero");
        __limitFadeOutRate = _limitFadeOut;
        
        //Convert the tag array into an array if necessary
        if (is_string(_tagArray)) _tagArray = [_tagArray];
        __tagArray = _tagArray;
        
        __effectChainName = _effectChainName ?? ((__parent == undefined)? "main" : __parent.__effectChainName);
        
        
        
        //Set remainder of the state
        __audioArray = [];
        __topLevelCount = 0;
        
        __gainLocal  = 1;
        __pitchLocal = 1;
        
        __gainTarget  = __gainLocal;
        __gainRate    = VINYL_DEFAULT_GAIN_RATE;
        __pitchTarget = __pitchLocal;
        __pitchRate   = VINYL_DEFAULT_PITCH_RATE;
        
        __gainOutput  = __gainLocal;
        __pitchOutput = __pitchLocal;
        
        if (VINYL_DEBUG_READ_CONFIG) __VinylTrace("Creating definition for ", self, ", gain=", __gainOutput, ", pitch=", __pitchOutput*__configPitchLo, " -> ", __pitchOutput*__configPitchHi, ", max instances=", __limitMaxCount);
    }
    
    #endregion
    
    
    
    #region Gain
    
    static __GainSet = function(_gain, _force = false)
    {
        if (VINYL_DEBUG_LEVEL >= 1)
        {
            __VinylTrace(self, " gain=", _gain);
        }
        
        if (!_force && __configGainKnob)
        {
            __VinylTrace(self, " gain is attached to a knob, cannot change gain manually");
            return;
        }
        
        __gainLocal  = _gain;
        __gainTarget = _gain;
    }
    
    static __GainGet = function()
    {
        return __gainLocal;
    }
    
    static __GainTargetSet = function(_targetGain, _rate)
    {
        if (VINYL_DEBUG_LEVEL >= 1)
        {
            __VinylTrace("Warning! ", self, " gain target=", _targetGain, ", rate=", _rate, "/s");
        }
        
        if (__configGainKnob)
        {
            __VinylTrace("Warning! ", self, " gain is attached to a knob, cannot set a target gain");
            return;
        }
        
        __gainTarget = _targetGain;
        __gainRate   = _rate;
    }
    
    static __GainTargetGet = function()
    {
        return __gainTarget;
    }
    
    static __GainOutputGet = function()
    {
        return __gainOutput;
    }
    
    #endregion
    
    
    
    #region Pitch
    
    static __PitchSet = function(_pitch, _force = false)
    {
        if (VINYL_DEBUG_LEVEL >= 1)
        {
            __VinylTrace(self, " pitch=", _pitch);
        }
        
        if (!_force && __configPitchKnob)
        {
            __VinylTrace("Warning! ", self, " pitch is attached to a knob, cannot change pitch manually");
            return;
        }
        
        __pitchLocal  = _pitch;
        __pitchTarget = _pitch;
    }
    
    static __PitchGet = function()
    {
        return __pitchLocal;
    }
    
    static __PitchTargetSet = function(_targetPitch, _rate)
    {
        if (VINYL_DEBUG_LEVEL >= 1)
        {
            __VinylTrace(self, " pitch target=", _targetPitch, ", rate=", _rate, "/s");
        }
        
        if (__configPitchKnob)
        {
            __VinylTrace("Warning! ", self, " pitch is attached to a knob, cannot set a target pitch");
            return;
        }
        
        __pitchTarget = _targetPitch;
        __pitchRate   = _rate;
    }
    
    static __PitchTargetGet = function()
    {
        return __pitchTarget;
    }
    
    static __PitchOutputGet = function()
    {
        return __pitchOutput;
    }
    
    #endregion
    
    
    
    #region Playback
    
    static __Stop = function()
    {
        if (VINYL_DEBUG_LEVEL >= 1) __VinylTrace("Stopping ", array_length(__audioArray), " audio instances playing (", self, ")");
        
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            VinylStop(__audioArray[_i]);
            ++_i;
        }
        
        array_resize(__audioArray, 0);
    }
    
    static __Pause = function()
    {
        if (VINYL_DEBUG_LEVEL >= 1) __VinylTrace("Pausing ", array_length(__audioArray), " audio instances playing (", self, ")");
        
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            VinylPause(__audioArray[_i]);
            ++_i;
        }
    }
    
    static __Resume = function()
    {
        if (VINYL_DEBUG_LEVEL >= 1) __VinylTrace("Resuming ", array_length(__audioArray), " audio instances playing (", self, ")");
        
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            VinylResume(__audioArray[_i]);
            ++_i;
        }
    }
    
    static __FadeOut = function(_rate)
    {
        if (VINYL_DEBUG_LEVEL >= 1) __VinylTrace("Fading out ", array_length(__audioArray), " audio instances (", self, ")");
        
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            VinylFadeOut(__audioArray[_i], _rate);
            ++_i;
        }
    }
    
    #endregion
    
    
    
    #region Queue
    
    static __QueuePush = function(_asset, _dontRepeatLast)
    {
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            if (VinylTypeGet(__audioArray[_i]) == "queue") VinylQueuePush(__audioArray[_i], _asset, _dontRepeatLast);
            ++_i;
        }
    }
    
    static __QueueBehaviorSet = function(_behavior)
    {
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            if (VinylTypeGet(__audioArray[_i]) == "queue") VinylQueueBehaviorSet(__audioArray[_i], _behavior);
            ++_i;
        }
    }
    
    #endregion
    
    
    
    #region Multi
    
    static __MultiGainSet = function(_index, _gain)
    {
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            if (VinylTypeGet(__audioArray[_i]) == "multi") VinylMultiGainSet(__audioArray[_i], _index, _gain);
            ++_i;
        }
    }
    
    static __MultiBlendSet = function(_blendFactor)
    {
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            if (VinylTypeGet(__audioArray[_i]) == "multi") VinylMultiBlendSet(__audioArray[_i], _blendFactor);
            ++_i;
        }
    }
    
    static __MultiSyncSet = function(_state)
    {
        var _i = 0;
        repeat(array_length(__audioArray))
        {
            if (VinylTypeGet(__audioArray[_i]) == "multi") VinylMultiSyncSet(__audioArray[_i], _state);
            ++_i;
        }
    }
    
    #endregion
    
    
    
    static __CopyOldState = function(_oldLabel)
    {
        __gainLocal  = _oldLabel.__gainLocal;
        __pitchLocal = _oldLabel.__pitchLocal;
        
        __gainTarget  = _oldLabel.__gainTarget;
        __gainRate    = _oldLabel.__gainRate;
        __pitchTarget = _oldLabel.__pitchTarget;
        __pitchRate   = _oldLabel.__pitchRate;
        
        if (VINYL_DEBUG_READ_CONFIG)
        {
            __VinylTrace("Copying state to ", self, ":");
            __VinylTrace("    gain in=", __gainLocal, "/out=", __gainOutput, ", pitch in=", __pitchLocal, "/out=", __pitchOutput);
            __VinylTrace("    gain target=", __gainTarget, ", rate=", __gainRate, "/s");
            __VinylTrace("    pitch target=", __pitchTarget, ", rate=", __pitchRate, "/s");
        }
    }
    
    static __InstanceAdd = function(_id)
    {
        if ((__limitMaxCount != undefined) && (__limitMaxCount >= 0))
        {
            var _topLevelCount = 0;
            
            //Iterate backwards
            var _i = array_length(__audioArray)-1;
            repeat(array_length(__audioArray))
            {
                var _instance = __idToInstanceDict[? __audioArray[_i]];
                if (_instance.__parentInstance == undefined)
                {
                    ++_topLevelCount;
                    if (_topLevelCount > __limitMaxCount)
                    {
                        if (VINYL_DEBUG_LEVEL >= 1) __VinylTrace(self, " will exceed ", __limitMaxCount, " playing instance(s), fading out oldest ", _instance);
                        
                        array_delete(__audioArray, _i, 1);
                        _instance.__FadeOut(__limitFadeOutRate);
                    }
                }
                
                --_i;
            }
        }
        
        //Add this instance to each label's playing array
        //Playing instances are removed from labels inside the label's __Tick() method
        //  N.B. This has no protection for duplicate entries!
        array_push(__audioArray, _id);
    }
              
    static __InstanceRemove = function(_id)
    {
        static _closure = {
            __value: undefined,
        };
        
        static _function = method(_closure, function(_value)
        {
            return (__value != _value);
        });
        
        _closure.__value = _id;
        array_resize(__audioArray, array_filter_ext(__audioArray, _function));
    }
    
    static __BuildAssetLabelArray = function(_labelArray, _labelDict)
    {
        if (!variable_struct_exists(_labelDict, __name))
        {
            _labelDict[$ __name] = self;
            array_push(_labelArray, self);
        }
        
        if (is_struct(__parent)) __parent.__BuildAssetLabelArray(_labelArray, _labelDict);
    }
    
    static __Tick = function(_deltaTimeFactor)
    {
        //Update input values based on gain/pitch target
        __gainLocal  += clamp(__gainTarget  - __gainLocal,  -_deltaTimeFactor*__gainRate,  _deltaTimeFactor*__gainRate );
        __pitchLocal += clamp(__pitchTarget - __pitchLocal, -_deltaTimeFactor*__pitchRate, _deltaTimeFactor*__pitchRate);
        
        __gainOutput  = __gainLocal*__configGain;
        __pitchOutput = __pitchLocal;
    }
}