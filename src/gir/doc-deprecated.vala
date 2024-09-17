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

public class Gir.DocDeprecated : Node {
    public bool xml_space_preserve {
        get {
            return attrs["xml:space"] == "preserve";
        }
        set {
            if (value) {
                attrs["xml:space"] = "preserve";
            } else {
                attrs.remove ("xml:space");
            }
        }
    }
    
    public bool xml_whitespace_preserve {
        get {
            return attrs["xml:whitespace"] == "preserve";
        }
        set {
            if (value) {
                attrs["xml:whitespace"] = "preserve";
            } else {
                attrs.remove ("xml:whitespace");
            }
        }
    }
    
    public string? text {
        owned get {
            return content;
        }
        set {
            content = value;
        }
    }
}

