package polymod.hscript._internal;

import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

using haxe.macro.TypeTools;

/**
 * Automatically adds the @:rtti metadata to classes with "Tools" or "Util" in their name
 */
class UsingRttiMacro
{
    public static macro function addRtti():Void
    {
        Context.onGenerate((types) ->
        {
            for (type in types)
            {
                if (type.toString().indexOf("Tools") != -1 )
                {
                    switch (type)
                    {
                        case TInst(_.get() => cls, _):
                            cls.meta.add(':rtti', [], cls.pos);
                        case _:
                    }
                }
            }
        });
    }
}
