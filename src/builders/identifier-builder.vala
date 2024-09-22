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

public class Builders.IdentifierBuilder {

    private Gir.Identifier identifier;

    public IdentifierBuilder (Gir.Identifier identifier) {
        this.identifier = identifier;
    }

    public virtual bool skip () {
        return ! identifier.introspectable;
    }

    /* Get the C prefix of this identifier */
    public string? get_ns_prefix () {
        var ns = identifier.parent_node as Gir.Namespace;

        /* Return null if this is not a registered type */
        if (ns == null) {
            return null;
        }

        return ns.c_identifier_prefixes ?? ns.c_prefix ?? ns.name;
    }

    /* Generate C name of an identifier: for example "GtkWindow" */
    public string? generate_cname () {
        var ns_prefix = get_ns_prefix ();
        return ns_prefix == null ? null : (ns_prefix + identifier.name);
    }

    /* Generate C name of the TypeClass/TypeInterface of a class/interface */
    public string? generate_type_cname () {
        if (identifier is Gir.Class) {
            return identifier.name + "Class";
        } else if (identifier is Gir.Interface) {
            return identifier.name + "Iface";
        } else {
            return null;
        }
    }
}
