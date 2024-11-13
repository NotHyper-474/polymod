package polymod.hscript._internal;

import haxe.macro.Printer;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using Lambda;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.ExprTools;

#if !macro
@:build(polymod.hscript._internal.HLNativeMacro.buildWrapperClass())
class HLMath extends Math {

}
#end

#if macro
/**
 * Macro that generates wrapper fields for a class with @:hlNative functions to make them avaliable to Polymod
 */
class HLNativeMacro
{
  public static macro function buildWrapperClass():Array<Field>
  {
    var localClass = Context.getLocalClass().get();
    var superClass = localClass.superClass;
    if (superClass == null)
      throw 'Class ${localClass.name} doesn\'t extend class it wants to wrap';
    var cls = superClass.t.get();
    var buildFields = Context.getBuildFields();

    for (field in cls.statics.get())
    {
      if (field.meta.get().exists(function(m) return m.name == ':hlNative')) {
        var wrapper = generateWrapper(field, cls);
        buildFields.push(wrapper);
      }
    }

    return buildFields;
  }

  static function generateWrapper(field:ClassField, cls:ClassType) {
    var fieldName = field.name;

    if (field == null || field.expr() == null)
      throw 'Field or field TypedExpr is null';

    var funcArgs:Array<FunctionArg> = [];
    var retType:Type = null;
    switch (field.expr().expr) {
        case TFunction(tfunc):
            for (arg in tfunc.args) {
              var isOpt = arg.value != null;
              var argExpr = arg.value == null ? null : Context.getTypedExpr(arg.value);
              var argType = TypeTools.toComplexType(arg.v.t);

              var funcArg:FunctionArg = {
                name: arg.v.name,
                type: argType,
                opt: isOpt,
                value: argExpr
              };
              funcArgs.push(funcArg);
            }
            retType = tfunc.t;
        default:
            throw 'Expected a function type for the field ${fieldName}';
    }

    var returnsVoid = doesReturnVoid(TypeTools.toComplexType(retType));

    // Create new parameters for the wrapper function that match the original method
    var callArgs:Array<Expr> = [for (arg in funcArgs) macro $i{arg.name}];
    var params = [for (param in field.params) {name: param.name}];
    var funcRet = returnsVoid ? null : TypeTools.toComplexType(retType);

    // Define the wrapper Field
    var expr = macro
    {
      $
      {
        // TODO: Do we need to use the class pack here?
        returnsVoid ? (macro $i{fieldName}($a{callArgs})) : (macro return $p{[cls.name, fieldName]}($a{callArgs}))
      }
    }
    var printer = new Printer();
    Context.info(printer.printExpr(expr), Context.currentPos());
    return {
        name: fieldName,
        doc: field.doc,
        meta: null,
        pos: field.pos,
        access: [APublic, AStatic, AInline],
        kind: FFun({
          args: funcArgs,
          params: params,
          ret: funcRet,
          expr: expr
          }
        )
    };
  }

  static function doesReturnVoid(rt:ComplexType) {
    return switch (rt) {
      case TPath(tp): tp.name == "Void";
      default: false;
    }
  }
}
#end
