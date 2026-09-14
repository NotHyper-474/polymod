package polymod.hscript._internal;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using Lambda;
using haxe.macro.Tools;
using StringTools;

/**
 * Macro that generates wrapper fields for substitutes of classes with `@:hlNative` to make them available to Reflection.
 * Currently only targets static fields.
 */
class HLWrapperMacro
{
  /**
   * A metadata that tells us if a class has already gone through this macro.
   */
  public static inline final PROCESS_FINISHED_META:String = ':polymodHlWrapped';

  public static function wrapClass():Array<Field>
  {
    if (!Context.defined('hl') || Context.defined('display')) return null;

    // Avoid types that aren't classes
    var cls:Null<ClassType> = Context.getLocalClass()?.get();
    if (cls == null || cls.isAbstract || cls.isExtern || cls.isInterface || cls.isPrivate) return null;

    if (cls.meta.has(PROCESS_FINISHED_META)) return null;
    cls.meta.add(PROCESS_FINISHED_META, [], cls.pos);

    var buildFields:Array<Field> = Context.getBuildFields();
    for (field in buildFields)
    {
      if (!field.access.contains(APublic)) continue;
      if (!field.access.contains(AStatic)) continue;

      var wrapper = generateWrapper(field);
      if (wrapper == null) continue;

      buildFields.push(wrapper);
    }

    return buildFields;
  }

  /**
   * Returns a wrapped version of a field, while modifying the original one to become hidden.
   * @param field
   * @return Null<Field>
   */
  static function generateWrapper(field:Field):Null<Field>
  {
    var metaNames:Array<String> = (field.meta ?? []).map(m -> m.name);

    // This is a function that has different versions
    if (metaNames.contains(':overload')) return null;
    if (!metaNames.contains(':hlNative') && !field.access.exists(access -> [AExtern, AOverride].contains(access))) return null;

    var newField:Field = Reflect.copy(field);
    var overrideName:String = '_override_${field.name}';

    switch (field.kind)
    {
      case FFun(fun):
        // Extern with no body.
        // Those are unsafe to replace.
        if (fun.expr == null)
          return null;

        var newFun:Function = Reflect.copy(fun);
        var callArgs:Array<Expr> = [for (arg in fun.args) macro $i{arg.name}];
        var body:Expr = macro $i{overrideName}($a{callArgs});

        newFun.expr = macro return $body;
        newField.kind = FFun(newFun);
        newField.meta = [];

        // Inline won't affect the access to reflection in this case,
        // and will actually optimize the overridden function call with the original one.
        newField.access = [APublic, AStatic];
        field.name = overrideName;
        field.access.remove(APublic);
      default:
        return null;
    }

    return newField;
  }
}
#end
