/// Adds an on-stop callback to a playback instance, or all instances assigned to the given label
/// 
/// This function CANNOT be used with audio played using VinylPlaySimple()
/// 
/// @param vinylID/labelName
/// @param callback
/// @param [callbackData]

function VinylStopCallbackSet(_id, _callback, _callbackData = undefined)
{
    static _globalData = __VinylGlobalData();
    static _idToInstanceDict = _globalData.__idToInstanceDict;
    
    var _instance = _idToInstanceDict[? _id];
    if (is_struct(_instance)) return _instance.__StopCallbackSet(_callback, _callbackData);
    
    var _label = _globalData.__labelDict[$ _id];
    if (is_struct(_label)) return _label.__StopCallbackSet(_callback, _callbackData);
}