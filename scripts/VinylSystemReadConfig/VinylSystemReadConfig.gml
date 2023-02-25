/// Reads in a data struct, seting asset and label definitions as required
/// This is useful for e.g. writing your own live mixing system
/// 
/// @param configData

function VinylSystemReadConfig(_configData)
{
    static _globalData = __VinylGlobalData();
    
    //Effect chain data structures are a bit special because they're never regenerated
    //We keep the old effect chains around so that we can dynamically update effects
    static _effectChainDict  = _globalData.__effectChainDict;
    static _effectChainArray = _globalData.__effectChainArray;
    
    var _oldKnobDict  = _globalData.__knobDict;
    var _oldLabelDict = _globalData.__labelDict;
    
    //Update our global data structures
    _globalData.__patternDict  = {};
    _globalData.__patternArray = [];
    _globalData.__knobDict     = {};
    _globalData.__knobArray    = [];
    _globalData.__labelDict    = {};
    _globalData.__labelOrder   = [];
    
    //Cache some values for a lil speed up
    var _newPatternDict = _globalData.__patternDict;
    var _newLabelOrder  = _globalData.__labelOrder;
    
    
    
    //Create new knobs and inherit values where possible
    var _inputKnobDict = _configData[$ "knobs"];
    if (is_undefined(_inputKnobDict))
    {
        __VinylTrace("Warning! \"knobs\" data missing");
    }
    else if (!is_struct(_inputKnobDict))
    {
        __VinylError("\"knobs\" data should be defined as an object (struct)");
    }
    else
    {
        var _knobNameArray = variable_struct_get_names(_inputKnobDict);
        var _i = 0;
        repeat(array_length(_knobNameArray))
        {
            var _knobName = _knobNameArray[_i];
            
            //Create a new knob
            var _newKnob = new __VinylClassKnob(_knobName);
            _newKnob.__Initialize(_inputKnobDict[$ _knobName]);
            _newKnob.__Store();
            _newKnob.__RestoreOldValue(_oldKnobDict);
            
            ++_i;
        }
    }
    
    
    
    //Instantiate labels, creating a dictionary for lookup and an array that contains the order to update the labels to respect parenting
    static _loadLabelsFunc = function(_loadLabelsFunc, _inputLabelDict, _parent)
    {
        var _nameArray = variable_struct_get_names(_inputLabelDict);
        var _i = 0;
        repeat(array_length(_nameArray))
        {
            var _labelName = _nameArray[_i];
            
            if (string_count(" ", _labelName) > 0)
            {
                __VinylTrace("Warning! Label names cannot contain spaces. \"", _labelName, "\" will be ignored");
                ++_i;
                continue;
            }
            
            var _labelData = _inputLabelDict[$ _labelName];
            var _label = new __VinylClassLabel(_labelName, _parent, false);
            _label.__Initialize(_labelData);
            _label.__Store();
            
            if (is_struct(_labelData) && variable_struct_exists(_labelData, "children"))
            {
                var _childrenDict = _labelData[$ "children"];
                if (is_struct(_childrenDict))
                {
                    _loadLabelsFunc(_loadLabelsFunc, _childrenDict, _label);
                }
                else
                {
                    __VinylTrace("Warning! Label \"", _labelName, "\" has an invalid \"children\" dictionary");
                }
            }
            
            ++_i;
        }
    }
    
    var _inputLabelDict = _configData[$ "labels"];
    if (is_undefined(_inputLabelDict))
    {
        __VinylTrace("Warning! \"labels\" data missing");
    }
    else if (!is_struct(_inputLabelDict))
    {
        __VinylError("\"labels\" data should be defined as an object (struct)");
    }
    else
    {
        _loadLabelsFunc(_loadLabelsFunc, _inputLabelDict, undefined);
        
        //Copy state data from old labels to new labels
        var _i = 0;
        repeat(array_length(_newLabelOrder))
        {
            var _newLabel = _newLabelOrder[_i];
            var _oldLabel = _oldLabelDict[$ _newLabel.__name];
            if (is_struct(_oldLabel)) _newLabel.__CopyOldState(_oldLabel);
            ++_i;
        }
    }
    
    
    
    //Instantiate basic patterns for each asset in the config data
    var _inputAssetDict = _configData[$ "assets"];
    if (is_undefined(_inputAssetDict))
    {
        __VinylTrace("Warning! \"assets\" data missing");
    }
    else if (!is_struct(_inputAssetDict))
    {
        __VinylError("\"assets\" data should be defined as an object (struct)");
    }
    else
    {
        var _assetNameArray = variable_struct_get_names(_inputAssetDict);
        var _i = 0;
        repeat(array_length(_assetNameArray))
        {
            var _assetName  = _assetNameArray[_i];
            var _assetIndex = asset_get_index(_assetName);
            
            if ((_assetIndex < 0) && (_assetName != "fallback"))
            {
                __VinylTrace("Warning! Asset \"", _assetName, "\" doesn't exist");
            }
            else if ((asset_get_type(_assetName) != asset_sound) && (_assetName != "fallback"))
            {
                __VinylTrace("Warning! Asset \"", _assetName, "\" isn't a sound");
            }
            else
            {
                var _key = (_assetName == "fallback")? "fallback" : string(_assetIndex);
                if (variable_struct_exists(_newPatternDict, _key))
                {
                    __VinylTrace("Warning! Asset \"", _key, "\" has already been defined");
                }
                else
                {
                    //Pull out the asset data
                    var _patternData = _inputAssetDict[$ _assetName];
                    
                    //Make a new pattern for this asset
                    if (_assetName == "fallback")
                    {
                        var _pattern = new __VinylClassPatternFallback();
                    }
                    else
                    {
                        var _pattern = new __VinylClassPatternBasic(_key, false);
                        _patternData.asset = _assetIndex; //Spoof a proper Basic pattern data struct
                    }
                    
                    _pattern.__Initialize(_patternData);
                    _pattern.__Store();
                    _pattern.__CopyTo(_patternData);
                }
            }
            
            ++_i;
        }
    }
    
    
    
    //Ensure we always have a fallback pattern
    if (!variable_struct_exists(_newPatternDict, "fallback"))
    {
        if (VINYL_DEBUG_READ_CONFIG) __VinylTrace("Fallback asset case doesn't exist, creating one");
        
        var _pattern = new __VinylClassPatternFallback();
        _pattern.__Initialize(undefined);
        _pattern.__Store();
    }
    
    
    
    //Iterate over every label and collect up sound assets with tags that match the label's definition
    var _i = 0;
    repeat(array_length(_newLabelOrder))
    {
        var _labelData = _newLabelOrder[_i];
        var _tagArray = _labelData.__tagArray;
        
        if (is_array(_tagArray))
        {
            var _j = 0;
            repeat(array_length(_tagArray))
            {
                var _tag = _tagArray[_j];
                var _assetArray = tag_get_asset_ids(_tag, asset_sound);
                if (is_array(_assetArray))
                {
                    var _k = 0;
                    repeat(array_length(_assetArray))
                    {
                        var _assetIndex = _assetArray[_k];
                        var _key = string(_assetIndex);
                        
                        var _pattern = _newPatternDict[$ _key];
                        if (_pattern == undefined)
                        {
                            _pattern = new __VinylClassPatternBasic(_key, false);
                            _pattern.__Initialize(undefined);
                            _pattern.__Store();
                        }
                        
                        _labelData.__LabelArrayAppend(_pattern.__labelArray);
                        
                        ++_k;
                    }
                }
                
                ++_j;
            }
        }
        
        ++_i;
    }
    
    
    
    //Iterate over every pattern in our input data and create a new pattern struct for each one
    var _inputPatternsDict = _configData[$ "patterns"];
    if (is_undefined(_inputAssetDict))
    {
        __VinylTrace("Warning! \"patterns\" data missing");
    }
    else if (!is_struct(_inputAssetDict))
    {
        __VinylError("\"patterns\" data should be defined as an object (struct)");
    }
    else
    {
        var _patternNameArray = variable_struct_get_names(_inputPatternsDict);
        var _i = 0;
        repeat(array_length(_patternNameArray))
        {
            var _patternName = _patternNameArray[_i];
            var _patternData = _inputPatternsDict[$ _patternName];
            
            if (!variable_struct_exists(_patternData, "type")) __VinylError("Pattern \"", _patternName, "\" doesn't have a \"type\" property");
            
            var _constructor = __VinylConvertPatternNameToConstructor(_patternName, _patternData.type);
            var _newPattern = new _constructor(_patternName, false);
            _newPattern.__Initialize(_patternData);
            _newPattern.__Store();
            
            ++_i;
        }
    }
    
    
    
    //Set up effect chains that we find in the incoming data
    var _inputEffectChainDict = _configData[$ "effect chains"];
    if (is_undefined(_inputAssetDict))
    {
        __VinylTrace("Warning! \"effect chains\" data missing");
    }
    else if (!is_struct(_inputAssetDict))
    {
        __VinylError("\"effect chains\" data should be defined as an object (struct)");
    }
    else
    {
        var _effectChainNameArray = variable_struct_get_names(_inputEffectChainDict);
        var _i = 0;
        repeat(array_length(_effectChainNameArray))
        {
            var _effectChainName = _effectChainNameArray[_i];
            __VinylEffectChainEnsure(_effectChainName).__Update(_inputEffectChainDict[$ _effectChainName]);
            ++_i;
        }
    }
    
    //Clean up any effect chains that exist in the old data but weren't in the incoming new data
    var _i = 0;
    repeat(array_length(_effectChainArray))
    {
        var _effectChain = _effectChainArray[_i];
        var _effectChainName = _effectChain.__name;
        
        if ((_effectChainName != "main") && !variable_struct_exists(_inputEffectChainDict, _effectChainName))
        {
            _effectChain.__Destroy();
            
            variable_struct_remove(_effectChainDict, _effectChainName);
            array_delete(_effectChainArray, _i, 1);
        }
        else
        {
            ++_i;
        }
    }
    
    
    
    //Migrate all of our patterns to the new dataset
    var _array = _globalData.__patternArray;
    var _i = 0;
    repeat(array_length(_array))
    {
        _array[_i].__Migrate();
        ++_i;
    }
    
    //Migrate all of our top-level instances to the new config data
    var _topLevelArray = _globalData.__topLevelArray;
    var _i = 0;
    repeat(array_length(_topLevelArray))
    {
        _topLevelArray[_i].__Migrate();
        ++_i;
    }
    
    //Update all values from knobs
    var _array = _globalData.__knobArray;
    var _i = 0;
    repeat(array_length(_array))
    {
        _array[_i].__Refresh();
        ++_i;
    }
    
    //Workaround for problems setting effects on the main audio effect bus in 2023.1
    gc_collect();
}