#macro __VINYL_VERSION  "2.0.0"
#macro __VINYL_DATE     "2021/04/10"

__VinylTrace("Welcome to Vinyl by @jujuadams! This is version " + __VINYL_VERSION + ", " + __VINYL_DATE);



FAudioGMS_Init(50, 1/60);

global.__vinylPlaying         = ds_list_create(); //TODO - Replace this with an array
global.__vinylGroupsList      = ds_list_create();
global.__vinylGroupsMap       = ds_map_create();
global.__vinylGlobalAssetGain = ds_map_create();
global.__vinylLibraryMap      = ds_map_create();



//Iterate over all audio assets and collect their start gain
var _i = 0;
repeat(9999)
{
    if (!audio_exists(_i)) break;
    global.__vinylGlobalAssetGain[? _i] = audio_sound_get_gain(_i);
    ++_i;
}



/// @param source
function __VinylPatternizeSource(_source)
{
    if (is_numeric(_source))
    {
        var _pattern = VinylLibGet(_source);
        if (_pattern == undefined) return new __VinylPatternBasic(_source);
        return _pattern;
    }
    else
    {
        return _source;
    }
}

#region Utility

/// @param [value...]
function __VinylTrace()
{
	var _string = "";
	var _i = 0;
	repeat(argument_count)
	{
	    _string += string(argument[_i]);
	    ++_i;
	}

	show_debug_message(string_format(current_time, 8, 0) + " Vinyl: " + _string);

	return _string;
}

/// @param [value...]
function __VinylError()
{
	var _string = "";
    
	var _i = 0;
	repeat(argument_count)
	{
	    _string += string(argument[_i]);
	    ++_i;
	}
    
	show_error("Vinyl:\n" + _string + "\n ", false);
    
	return _string;
}

function __VinylGroupArrayToString(_array)
{
    var _size = array_length(_array);
    var _string = "[";
    
    if (_size > 0)
    {
        var _i = 0;
        var _value = _array[_i];
        if (weak_ref_alive(_value)) _string += string(_array[_i].ref);
        
        _i = 1;
        repeat(_size - 1)
        {
            var _value = _array[_i];
            if (weak_ref_alive(_value)) _string += "," + string(_array[_i].ref);
            ++_i;
        }
    }
    
    return _string + "]";
}

#endregion