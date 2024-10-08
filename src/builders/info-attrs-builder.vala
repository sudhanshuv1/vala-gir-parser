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

public class Builders.InfoAttrsBuilder {

    private Gir.Node g_info_attrs;

    public InfoAttrsBuilder (Gir.Node g_info_attrs) {
        this.g_info_attrs = g_info_attrs;
    }

    public void add_info_attrs (Vala.Symbol v_sym) {
        /* version */
        v_sym.version.since = g_info_attrs.get_string ("version");

        /* deprecated and deprecated_since */
        if (g_info_attrs.get_bool ("deprecated")) {
            /* omit deprecation attributes when the parent already has them */
            if (g_info_attrs.parent_node.get_bool ("deprecated")) {
                return;
            }

            v_sym.version.deprecated = true;
            var since = g_info_attrs.get_string ("deprecated-version");
            v_sym.version.deprecated_since = since;
        }

        if ("experimental" in g_info_attrs.attrs) {
            var experimental = g_info_attrs.get_bool ("experimental");
            v_sym.set_attribute_bool ("Version", "experimental", experimental);
        }

        if ("instance-idx" in g_info_attrs.attrs) {
            var idx = (double) g_info_attrs.get_int ("instance-idx");
            v_sym.set_attribute_double ("CCode", "instance_pos", idx + 0.5);
        }

        if ("hides" in g_info_attrs.attrs) {
            v_sym.hides = g_info_attrs.get_bool ("hides");
        }

        if (g_info_attrs.get_bool ("floating") && v_sym is Vala.Method) {
            unowned var v_method = (Vala.Method) v_sym;
            v_method.returns_floating_reference = true;
            v_method.return_type.value_owned = true;
        }

		if (g_info_attrs.has_attr ("glib:finish-func")) {
            var finish_func = g_info_attrs.get_string ("glib:finish-func");
            var expected = g_info_attrs.get_string ("name") + "_finish";
            if (finish_func != expected) {
                v_sym.set_attribute_string ("CCode", "finish_name", finish_func);
            }
		}

        if (g_info_attrs.has_attr ("finish-vfunc-name")) {
            var name = g_info_attrs.get_string ("finish-vfunc-name");
			v_sym.set_attribute_string ("CCode", "finish_vfunc_name", name);
		}

        if (g_info_attrs.has_attr ("finish-instance")) {
            var name = g_info_attrs.get_string ("finish-instance");
			v_sym.set_attribute_string ("CCode", "finish_instance", name);
		}

        if ("feature-test-macro" in g_info_attrs.attrs) {
            var macro = g_info_attrs.get_string ("feature-test-macro");
            v_sym.set_attribute_string ("CCode", "feature_test_macro", macro);
        }

        if ("delegate-target" in g_info_attrs.attrs) {
            var dlg_target = g_info_attrs.get_bool ("delegate-target");
            v_sym.set_attribute_bool ("CCode", "delegate_target", dlg_target);
        }

        if ("printf-format" in g_info_attrs.attrs) {
            var printf_format = g_info_attrs.get_bool ("printf-format");
            v_sym.set_attribute ("PrintfFormat", printf_format);
        }

        if ("returns-modified-pointer" in g_info_attrs.attrs) {
            var ret_mod_p = g_info_attrs.get_bool ("returns-modified-pointer");
            v_sym.set_attribute ("ReturnsModifiedPointer", ret_mod_p);
        }
    }
}
