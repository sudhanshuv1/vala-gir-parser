/* vala-gir-parser
 * Copyright (C) 2024-2025 Jan-Willem Harmannij
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
using Builders;

public class GirMetadata.MetadataProcessor {

    private Vala.List<Metadata> metadata_stack = new ArrayList<Metadata> ();
    private Gir.Node repository;

    public MetadataProcessor (Gir.Node repository) {
        this.repository = repository;
    }

    public void apply (Metadata metadata) {
        metadata_stack.add (metadata);
        process_node (ref repository);
        metadata_stack.clear ();
    }

    private void process_node (ref Gir.Node node) {
        string[] relevant_types = {
            "alias", "bitfield", "glib:boxed", "callback", "constructor",
            "class", "enumeration", "function", "instance-parameter",
            "interface", "member", "method", "namespace", "parameter",
            "property", "record", "glib:signal", "union", "virtual-method"
        };
        
        if (node.tag in relevant_types) {
            push_metadata (node.get_string ("name"), node.tag);
            apply_metadata (ref node, node.tag);
        }

        if (node.tag == "namespace" && node.parent_node.tag == "repository") {
            pop_metadata ();
        }

        /* no need to process child nodes when the parent node is skipped */
        if (node.get_bool ("introspectable", true)) {
            for (int i = 0; i < node.children.size; i++) {
                var child_node = node.children[i];
                process_node (ref child_node);

                /* when a child node was reparented, stay on the same index */
                if (child_node.parent_node != node) {
                    i--;
                }
            }
        }
        
        if (node.tag in relevant_types) {
            pop_metadata ();
        }
    }

    /* Apply metadata rules to this gir node. The changes are applied in-place,
     * destructively. It is possible that the node is completely replaced by
     * another node (possibly with another type) or moved to another location in
     * the tree. */
    private void apply_metadata (ref Gir.Node node, string tag) {
        var metadata = peek_metadata ();
        var source = metadata.source_reference;

        if (metadata.has_argument (SKIP)) {
            node.set_bool ("introspectable", ! metadata.get_bool (SKIP));
        }

        if (metadata.has_argument (HIDDEN)) {
            /* Unsure what to do with this; treat the same as 'skip' */
            node.set_bool ("introspectable", ! metadata.get_bool (HIDDEN));
        }

        if (metadata.has_argument (NEW)) {
            node.set_bool ("vala:hides", metadata.get_bool (NEW));
        }

        if (metadata.has_argument (TYPE)) {
            node.remove ("type", "array");
            var expr = metadata.get_string (TYPE);
            var datatype = DataTypeBuilder.from_expression (expr);
            datatype.source_reference = source;
            node.add (DataTypeBuilder.vala_datatype_to_gir (datatype));
        }

        if (metadata.has_argument (TYPE_ARGUMENTS)) {
            var current_type = node.any_of ("type", "array");
            if (current_type == null && node.has_any ("return-value")) {
                current_type = node.any_of ("return-value")
                                   .any_of ("type", "array");
            }

            if (current_type == null) {
                Report.error (source, "Cannot set type arguments of %s", tag);
            } else {
                string type_args = metadata.get_string (TYPE_ARGUMENTS);
                foreach (var type_arg in type_args.split (",")) {
                    var datatype = DataTypeBuilder.from_expression (type_arg);
                    datatype.source_reference = source;
                    var new_type = DataTypeBuilder.vala_datatype_to_gir (datatype);
                    current_type.add (new_type);
                }
            }
        }

        if (metadata.has_argument (CHEADER_FILENAME) && tag == "namespace") {
            var repo = node.parent_node;
            repo.remove ("c:include");

            var headers = metadata.get_string (CHEADER_FILENAME);
            foreach (var c_include in headers.split (",")) {
                var c_incl_node = Gir.Node.create ("c:include", source,
                    "name", c_include);
                repo.add (c_incl_node);
            }
        }

        if (metadata.has_argument (NAME)) {
            var pattern = metadata.get_string (ArgumentType.NAME);
            var name = node.get_string ("name");
            if (pattern != null) {
                replace_name_with_pattern(ref name, pattern);
                node.set_string ("name", name);
            }
        }

        if (metadata.has_argument (OWNED)) {
            var transfer = metadata.get_bool (OWNED) ? "full" : "none";
            if (tag == "parameter") {
                node.set_string ("transfer-ownership", transfer);
            } else if (node.has_any ("return-value")) {
                node.any_of ("return-value")
                    .set_string ("transfer-ownership", transfer);
            }
        }

        if (metadata.has_argument (UNOWNED)) {
            var transfer = metadata.get_bool (UNOWNED) ? "none" : "full";
            if (tag == "parameter") {
                node.set_string ("transfer-ownership", transfer);
            } else if (node.has_any ("return-value")) {
                node.any_of ("return-value")
                    .set_string ("transfer-ownership", transfer);
            }
        }

        if (metadata.has_argument (PARENT)) {
            var path = metadata.get_string (PARENT);
            var location = find_or_create_gir_node (path, source);
            node.parent_node.children.remove (node);
            location.add (node);
        }

        if (metadata.has_argument (NULLABLE)) {
            var nullable = metadata.get_bool (NULLABLE);
            if (tag == "parameter") {
                node.set_bool ("nullable", nullable);
            } else if (node.has_any ("return-value")) {
                node.any_of ("return-value")
                    .set_bool ("nullable", nullable);
            }
        }

        if (metadata.has_argument (DEPRECATED)) {
            var deprecated = metadata.get_bool (DEPRECATED);
            node.set_bool ("deprecated", deprecated);
        }

        if (metadata.has_argument (REPLACEMENT)) {
            var replacement = metadata.get_string (REPLACEMENT);
            node.set_string ("moved-to", replacement);
        }
        
        if (metadata.has_argument (DEPRECATED_SINCE)) {
            var deprecated_since = metadata.get_string (DEPRECATED_SINCE);
            node.set_string ("deprecated-version", deprecated_since);
            node.set_bool ("deprecated", true);
        }

        if (metadata.has_argument (SINCE)) {
            node.set_string ("version", metadata.get_string (SINCE));
        }

        if (metadata.has_argument (ARRAY)) {
            var current_type = node.any_of ("type", "array");
            if (current_type == null && node.has_any ("return-value")) {
                current_type = node.any_of ("return-value")
                                   .any_of ("type", "array");
            }

            var array = Gir.Node.create ("array", source);
            array.add (current_type);

            var parent = current_type.parent_node;
            parent.remove ("type", "array");
            parent.add (array);
        }

        if (metadata.has_argument (ARRAY_LENGTH_IDX)) {
            var array = node.any_of ("array");
            if (array == null && node.has_any ("return-value")) {
                array = node.any_of ("return-value").any_of ("array");
            }

            if (array == null) {
                Report.warning (source, "Cannot set array_length_idx on %s", tag);
            } else {
                var array_length_idx = metadata.get_integer (ARRAY_LENGTH_IDX);
                array.set_int ("length", array_length_idx);
            }
        }

        if (metadata.has_argument (ARRAY_NULL_TERMINATED)) {
            var array = node.any_of ("array");
            if (array == null && node.has_any ("return-value")) {
                array = node.any_of ("return-value").any_of ("array");
            }

            if (array == null) {
                Report.error (source, "Cannot set array_null_terminated on %s", tag);
            } else {
                var null_terminated = metadata.get_bool (ARRAY_NULL_TERMINATED);
                array.set_bool ("zero-terminated", null_terminated);
            }
        }

        if (metadata.has_argument (DEFAULT)) {
            node.set_expression ("vala:default", metadata.get_expression (DEFAULT));
        }

        if (metadata.has_argument (OUT)) {
            var is_out = metadata.get_bool (OUT);
            node.set_string ("direction", is_out ? "out" : "in");
        }

        if (metadata.has_argument (REF)) {
            var is_ref = metadata.get_bool (REF);
            node.set_string ("direction", is_ref ? "inout" : "in");
        }

        if (metadata.has_argument (VFUNC_NAME)) {
            string vm_name = metadata.get_string (VFUNC_NAME);
            string invoker_name = node.get_string ("name");
            bool found = false;
            foreach (var vm in node.parent_node.all_of ("virtual-method")) {
                if (vm.get_string ("name") == vm_name) {
                    vm.set_string ("invoker", invoker_name);
                    found = true;
                    break;
                }
            }

            if (! found) {
                Report.error (source, "Cannot find vfunc named '%s'", vm_name);
            }
        }

        if (metadata.has_argument (VIRTUAL)) {
            if (metadata.get_bool (VIRTUAL)) {
                node.tag = "virtual-method";
            } else {
                node.tag = "method";
            }
        }

        if (metadata.has_argument (ABSTRACT)) {
            node.set_bool ("abstract", metadata.get_bool (ABSTRACT));
        }

        if (metadata.has_argument (COMPACT)) {
            node.set_bool ("vala:compact", metadata.get_bool (COMPACT));
        }

        if (metadata.has_argument (SEALED)) {
            node.set_bool ("final", metadata.get_bool (SEALED));
        }

        if (metadata.has_argument (SCOPE)) {
            node.set_string ("scope", metadata.get_string (SCOPE));
        }

        if (metadata.has_argument (STRUCT)) {
            node.set_bool ("vala:struct", metadata.get_bool (STRUCT));
        }

        if (metadata.has_argument (THROWS)) {
            node.set_bool ("throws", metadata.get_bool (THROWS));
        }

        if (metadata.has_argument (PRINTF_FORMAT)) {
            var printf_format = metadata.get_bool (PRINTF_FORMAT);
            node.set_bool ("vala:printf-format", printf_format);
        }

        if (metadata.has_argument (ARRAY_LENGTH_FIELD)) {
            var field_name = metadata.get_string (ARRAY_LENGTH_FIELD);
            var array = node.any_of ("array");
            if (array == null) {
                Report.error (source, "Cannot set array length field on %s", tag);
            } else {
                var fields = node.parent_node.all_of ("field");
                bool found = false;
                for (int i = 0; i < fields.size; i++) {
                    if (fields[i].get_string ("name") == field_name) {
                        array.set_int ("length", i);
                        found = true;
                        break;
                    }
                }

                if (! found) {
                    Report.error (source, "Cannot find field named '%s'", field_name);
                }
            }
        }

        if (metadata.has_argument (SENTINEL)) {
            node.set_string ("vala:sentinel", metadata.get_string (SENTINEL));
        }

        if (metadata.has_argument (CLOSURE)) {
            var closure = metadata.get_integer (CLOSURE);
            if (node.has_any ("return-value")) {
                node.any_of ("return-value").set_int ("closure", closure);
            } else {
                node.set_int ("closure", closure);
            }
        }

        if (metadata.has_argument (DESTROY)) {
            var destroy = metadata.get_integer (DESTROY);
            if (node.has_any ("return-value")) {
                node.any_of ("return-value").set_int ("destroy", destroy);
            } else {
                node.set_int ("destroy", destroy);
            }
        }

        if (metadata.has_argument (ERRORDOMAIN)) {
            var error_domain = metadata.get_string (ERRORDOMAIN);
            node.set_string ("glib:error-domain", error_domain);
        }

        if (metadata.has_argument (DESTROYS_INSTANCE) && tag == "method") {
            /* a method destroys its instance when ownership is transferred to
             * the instance parameter */
            node.any_of ("parameters")
                .any_of ("instance-parameter")
                .set_string ("transfer-ownership", "full");
        }

        if (metadata.has_argument (BASE_TYPE)
                && (tag == "alias" || tag == "glib:boxed")) {
            node.set_string ("parent", metadata.get_string (BASE_TYPE));
        }

        if (metadata.has_argument (FINISH_NAME)) {
            var finish_name = metadata.get_string (FINISH_NAME);
            node.set_string ("glib:finish-func", finish_name);
        }

        if (metadata.has_argument (FINISH_INSTANCE)) {
            var finish_instance = metadata.get_string (FINISH_INSTANCE);
            node.set_string ("vala:finish-instance", finish_instance);
        }

        if (metadata.has_argument (SYMBOL_TYPE)) {
            node.tag = metadata.get_string (SYMBOL_TYPE);
        }

        if (metadata.has_argument (INSTANCE_IDX)) {
            node.set_int ("vala:instance-idx", metadata.get_integer (INSTANCE_IDX));
        }

        if (metadata.has_argument (EXPERIMENTAL)) {
            node.set_bool ("vala:experimental", metadata.get_bool (EXPERIMENTAL));
        }

        if (metadata.has_argument (FEATURE_TEST_MACRO)) {
            var macro = metadata.get_string (FEATURE_TEST_MACRO);
            node.set_string ("vala:feature-test-macro", macro);
        }

        if (metadata.has_argument (FLOATING)) {
            node.set_bool ("vala:floating", metadata.get_bool (FLOATING));
        }

        if (metadata.has_argument (TYPE_ID)) {
            node.set_string ("glib:get-type", metadata.get_string (TYPE_ID));
        }

        if (metadata.has_argument (TYPE_GET_FUNCTION)) {
            var type_get_function = metadata.get_string (TYPE_GET_FUNCTION);
            node.set_string ("vala:type-get-function", type_get_function);
        }

        if (metadata.has_argument (COPY_FUNCTION)) {
            var copy_func = metadata.get_string (COPY_FUNCTION);
            node.set_string ("copy-function", copy_func);
        }

        if (metadata.has_argument (FREE_FUNCTION)) {
            var free_func = metadata.get_string (FREE_FUNCTION);
            node.set_string ("free-function", free_func);
        }

        if (metadata.has_argument (REF_FUNCTION)) {
            var ref_func = metadata.get_string (REF_FUNCTION);
            node.set_string ("glib:ref-func", ref_func);
        }

        if (metadata.has_argument (REF_SINK_FUNCTION)) {
            var ref_sink_func = metadata.get_string (REF_SINK_FUNCTION);
            node.set_string ("vala:ref-sink-function", ref_sink_func);
        }

        if (metadata.has_argument (UNREF_FUNCTION)) {
            var unref_func = metadata.get_string (UNREF_FUNCTION);
            node.set_string ("glib:unref-func", unref_func);
        }

        if (metadata.has_argument (RETURN_VOID)) {
            // TODO: Undo the gir-transformation
        }

        if (metadata.has_argument (RETURNS_MODIFIED_POINTER)) {
            var ret_mod_p = metadata.get_bool (RETURNS_MODIFIED_POINTER);
            node.set_bool ("vala:returns-modified-pointer", ret_mod_p);
        }

        if (metadata.has_argument (DELEGATE_TARGET_CNAME)) {
            var cname = metadata.get_string (DELEGATE_TARGET_CNAME);
            node.set_string ("vala:delegate-target-cname", cname);
        }

        if (metadata.has_argument (DESTROY_NOTIFY_CNAME)) {
            var cname = metadata.get_string (DESTROY_NOTIFY_CNAME);
            node.set_string ("vala:destroy-notify-cname", cname);
        }

        if (metadata.has_argument (FINISH_VFUNC_NAME)) {
            var name = metadata.get_string (FINISH_VFUNC_NAME);
            node.set_string ("vala:finish-vfunc-name", name);
            node.tag = "virtual-method";
        }

        if (metadata.has_argument (NO_ACCESSOR_METHOD)) {
            var no_accessor_method = metadata.get_bool (NO_ACCESSOR_METHOD);
            node.set_bool ("vala:no-accessor-method", no_accessor_method);
        }

        if (metadata.has_argument (CNAME)) {
            node.set_string ("c:type", metadata.get_string (CNAME));
        }

        if (metadata.has_argument (DELEGATE_TARGET)) {
            var delegate_target = metadata.get_bool (DELEGATE_TARGET);
            node.set_bool ("vala:delegate-target", delegate_target);
        }

        if (metadata.has_argument (CTYPE)) {
            node.set_string ("c:type", metadata.get_string (CTYPE));
        }
    }

    /* helper function for processing the NAME metadata attribute */
    private void replace_name_with_pattern (ref string name, string pattern) {
        if (pattern.index_of_char ('(') < 0) {
            /* shortcut for "(.+)/replacement" */
            name = pattern;
        } else {
            try {
                /* replace the whole name with the match by default */
                string replacement = "\\1";
                var split = pattern.split ("/");
                if (split.length > 1) {
                    pattern = split[0];
                    replacement = split[1];
                }
                var regex = new Regex (pattern, ANCHORED, ANCHORED);
                name = regex.replace (name, -1, 0, replacement);
            } catch (Error e) {
                name = pattern;
            }
        }
    }

    /* Find the node with the requested path down the gir tree. If not found, a
     * new namespace is created for the remaining part of the path. */
    private Gir.Node find_or_create_gir_node (string path,
                                              SourceReference? source) {
        Gir.Node current_node = repository;
        foreach (string name in path.split(".")) {
            if (! move_down_gir_tree (ref current_node, name)) {
                var ns = Gir.Node.create ("namespace", source, "name", name);
                current_node.add (ns);
                current_node = ns;
            }
        }

        return current_node;
    }

    /* Replace `current_node` with a child node with the requested name, if it
     * is a namespace or type identifier (class, interface, record etc). */
    private bool move_down_gir_tree (ref Gir.Node current_node, string name) {
        string[] relevant_types = {
            "alias", "bitfield", "glib:boxed", "callback", "class",
            "enumeration", "interface", "namespace", "record", "union"
        };

        foreach (var child in current_node.children) {
            if (child.tag in relevant_types
                    && (child.get_string ("name") == name)) {
                current_node = child;
                return true;
            }
        }

        return false;
    }

    private void push_metadata (string? name, string tag) {
        metadata_stack.add (get_current_metadata (name, tag));
    }

    private Metadata peek_metadata () {
        return metadata_stack.last ();
    }

    private void pop_metadata () {
        metadata_stack.remove_at (metadata_stack.size - 1);
    }

    private Metadata get_current_metadata (string? name, string tag) {
        var selector = tag.replace ("glib:", "");

        /* Give a transparent union the generic name "union" */
        if (selector == "union" && name == null) {
            name = "union";
        }

        if (name == null) {
            return Metadata.empty;
        }
        
        var child_selector = selector.replace ("-", "_");
        var child_name = name.replace ("-", "_");
        var result = peek_metadata ().match_child (child_name, child_selector);
        return result;
    }
}
