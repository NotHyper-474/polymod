package polymod.hscript._internal;

import haxe.macro.MacroStringTools;
import haxe.macro.TypedExprTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using Lambda;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.ExprTools;
using StringTools;

#if (!macro && hl)
@:build(polymod.hscript._internal.HLWrapperMacro.buildWrapperClass())
class HLMath extends Math {}

@:build(polymod.hscript._internal.HLWrapperMacro.buildWrapperClass())
@:haxe.warning("-WDeprecated")
class HLStd extends Std {
  public static inline function downcast<T:{}, S:T>(value:T, c:Class<S>):S {
    return Std.downcast(value, c);
  }
}
#else

/**
 * Macro that generates wrapper fields for substitutes of `std` classes to make them avaliable to Reflection
 */
class HLWrapperMacro
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
      if (field.isPublic) {
        var wrapper = generateWrapper(field, cls);
        if (wrapper != null)
          buildFields.push(wrapper);
      }
    }

    return buildFields;
  }

  static function generateWrapper(field:ClassField, cls:ClassType):Field {
    var fieldName = field.name;

    if (field == null)
      throw 'Field is null';

    if (field.name.contains("instance")) return null;

    if (field.expr() == null)
    {
      if (field.isExtern) return null;

      var varType = Context.toComplexType(field.type);
      return {
        name: fieldName,
        doc: field.doc,
        meta: null,
        pos: field.pos,
        access: [APublic, AStatic],
        kind: FVar(varType, Context.parseInlineString('${cls.name}.${fieldName}', field.pos))
      };
    }

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
            throw 'Expected a function or variable type for the field ${fieldName}';
    }

    var returnsVoid = doesReturnVoid(Context.toComplexType(retType));

    // Create new parameters for the wrapper function that match the original method
    var callArgs:Array<Expr> = [for (arg in funcArgs) macro $i{arg.name}];
    var params = [for (param in field.params) {name: param.name}];
    var funcRet = returnsVoid ? null : Context.toComplexType(retType);

    // Define the wrapper Field
    var expr = macro
    {
      $
      {
        returnsVoid ? (macro $p{[cls.name, fieldName]}($a{callArgs})) : (macro return $p{[cls.name, fieldName]}($a{callArgs}))
      }
    }
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
