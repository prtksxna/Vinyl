/// @param vinylID
/// @param index

function VinylMultiGainGet(_id, _index)
{
    static _globalData = __VinylGlobalData();
    static _idToInstanceDict = _globalData.__idToInstanceDict;
    
    var _instance = _idToInstanceDict[? _id];
    if (is_struct(_instance)) return _instance.__MultiGainGet(_index);
}