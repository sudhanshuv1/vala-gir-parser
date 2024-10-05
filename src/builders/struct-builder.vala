/* vala-gir-parser
 * Copyright (C) 2024 Jan-Willem Harmannij
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, see <http://www.gnu.org/licenses/>.
 */

using Vala;

public class Builders.StructBuilder : IdentifierBuilder {

    private Gir.Node g_rec;

    public StructBuilder (Gir.Node g_rec) {
        base (g_rec);
        this.g_rec = g_rec;
    }

    public Vala.Struct build () {
        /* the struct */
        Vala.Struct v_struct = new Vala.Struct (g_rec.get_string ("name"), g_rec.source);
        v_struct.access = PUBLIC;

        /* c_name */
        var c_type = g_rec.get_string ("c:type");
        if (c_type != generate_cname ()) {
            v_struct.set_attribute_string ("CCode", "cname", c_type);
        }

        /* version */
        new InfoAttrsBuilder (g_rec).add_info_attrs (v_struct);

        /* get_type method */
        var type_id = g_rec.get_string ("glib:get-type");
        if (type_id == null) {
            v_struct.set_attribute_bool ("CCode", "has_type_id", false);
        } else {
            v_struct.set_attribute_string ("CCode", "type_id", type_id + " ()");
        }

        /* add constructors */
        foreach (var g_ctor in g_rec.all_of ("constructor")) {
            var builder = new MethodBuilder (g_ctor);
            if (! builder.skip ()) {
                v_struct.add_method (builder.build_constructor ());
            } 
        }

        /* add functions */
        foreach (var g_function in g_rec.all_of ("function")) {
            var builder = new MethodBuilder (g_function);
            if (! builder.skip ()) {
                v_struct.add_method (builder.build_function ());
            } 
        }

        /* add methods */
        foreach (var g_method in g_rec.all_of ("method")) {
            var builder = new MethodBuilder (g_method);
            if (! builder.skip ()) {
                v_struct.add_method (builder.build_method ());
            } 
        }

        /* add fields */
        int i = 0;
        foreach (var g_field in g_rec.all_of ("field")) {
            /* exclude first (parent) field */
            if (i++ == 0 && g_rec.has_attr ("glib:is-gtype-struct-for")) {
                continue;
            }

            var field_builder = new FieldBuilder (g_field);
            if (! field_builder.skip ()) {
                v_struct.add_field (field_builder.build ());
            }
        }

        return v_struct;
    }

    public override bool skip () {
        return (base.skip ())
                || g_rec.has_attr ("glib:is-gtype-struct-for");
    }
}
