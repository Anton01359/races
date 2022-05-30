/*

Copyright (c) 2022, Neil J. Tan
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

$(function() {
    let replyOpen = false;
    let confirmOpen = false;
    let openPanel = "";
    let pvtTrackNames = "";
    let pubTrackNames = "";
    let pvtGrpNames = "";
    let pubGrpNames = "";
    var action
    var access

    function select_action(object, action, name) {
        if (object == "track") {
            return (function() {
                $.post(action, JSON.stringify({
                    access: $("#edit_track_access0").val(),
                    trackName: $(name).val()
                }));
            });
        } else if (object == "ai_group") {
            return (function() {
                $.post(action, JSON.stringify({
                    access: $("#grp_access0").val(),
                    name: $(name).val()
                }));
            });
        } else if (object == "ai") {
            return (function() {
                $.post(action, JSON.stringify({
                    aiName: $(name).val()
                }));
            });
        };
    };
     
    $("#supportPanel").hide();
    $("#editPanel").hide();
    $("#registerPanel").hide();
    $("#replyPanel").hide();
    $("#confirmPanel").hide();

    window.addEventListener("message", function(event) {
        let data = event.data;
        if ("register" == data.panel) {
            $("#buyin").val(data.defaultBuyin);
            $("#laps").val(data.defaultLaps);
            $("#timeout").val(data.defaultTimeout);
            $("#delay").val(data.defaultDelay);
            $("#rtype").change();
            $("#registerPanel").show();
            openPanel = "register";
        } else if ("edit" == data.panel) {
            $("#editPanel").show();
            openPanel = "edit";
        } else if ("support" == data.panel) {
            $("#supportPanel").show();
            openPanel = "support";
        } else if ("reply" == data.panel) {
            $("#supportPanel").hide();
            $("#editPanel").hide();
            $("#registerPanel").hide();
            document.getElementById("message").innerHTML = data.message;
            $("#replyPanel").show();
            replyOpen = true;
        } else if ("trackNames" == data.update) {
            if ("pvt" == data.access) {
                pvtTrackNames = data.trackNames;
            } else if ("pub" == data.access) {
                pubTrackNames = data.trackNames;
            };
            $("#support_track_access").change()
            $("#edit_track_access0").change()
            $("#register_track_access").change()
        } else if ("grpNames" == data.update) {
            if ("pvt" == data.access) {
                pvtGrpNames = data.grpNames;
            } else if ("pub" == data.access) {
                pubGrpNames = data.grpNames;
            };
            $("#grp_access0").change()
        } else if ("edit_close" == data.panel) {
            $("#editPanel").hide();
            $.post("https://races/close");
        };
    });

    /* register panel */
    $("#register_track_access").change(function() {
        if ("pvt" == $("#register_track_access").val()) {
            document.getElementById("register_name").innerHTML = pvtTrackNames;
        } else {
            document.getElementById("register_name").innerHTML = pubTrackNames;
        };
    });

    $("#register_load").click(function() {
        $.post("https://races/load", JSON.stringify({
            access: $("#register_track_access").val(),
            trackName: $("#register_name").val()
        }));
    });

    $("#register_blt").click(function() {
        $.post("https://races/blt", JSON.stringify({
            access: $("#register_track_access").val(),
            trackName: $("#register_name").val()
        }));
    });

    $("#register_list").click(function() {
        $.post("https://races/list", JSON.stringify({
            access: $("#register_track_access").val()
        }));
    });

    $("#rtype").change(function() {
        if ($("#rtype").val() == "norm") {
            $("#rest").hide();
            $("#file").hide();
            $("#vclass").hide();
            $("#rclass").hide();
            $("#sveh").hide();
        } else if ($("#rtype").val() == "rest") {
            $("#rest").show();
            $("#file").hide();
            $("#vclass").hide();
            $("#rclass").hide();
            $("#sveh").hide();
        } else if ($("#rtype").val() == "class") {
            $("#rest").hide();
            if ($("#register_vclass").val() == "-1") {
                $("#file").show();
            } else {
                $("#file").hide();
            };
            $("#vclass").show();
            $("#rclass").hide();
            $("#sveh").hide();
        } else if ($("#rtype").val() == "rand") {
            $("#rest").hide();
            $("#file").show();
            $("#vclass").hide();
            $("#rclass").show();
            $("#sveh").show();
        };
    });

    $("#register_vclass").change(function() {
        if ($("#rtype").val() == "class") {
            if ($("#register_vclass").val() == "-1") {
                $("#file").show();
            } else {
                $("#file").hide();
            };
        };
    });

    $("#register").click(function() {
        $.post("https://races/register", JSON.stringify({
            buyin: $("#buyin").val(),
            laps: $("#laps").val(),
            timeout: $("#timeout").val(),
            allowAI: $("#allowAI").val(),
            rtype: $("#rtype").val(),
            restrict: $("#restrict").val(),
            filename: $("#filename").val(),
            vclass: $("#register_vclass").val(),
            vclass: $("#register_rclass").val(),
            svehicle: $("#svehicle").val()
        }));
    });

    $("#unregister").click(function() {
        $.post("https://races/unregister");
    });

    $("#start").click(function() {
        $("#registerPanel").hide();
        $.post("https://races/close");
        $.post("https://races/start", JSON.stringify({
            delay: $("#delay").val()
        }));
    });

    $("#spawn_ai").click(function() {
        $("#registerPanel").hide();
        $.post("https://races/close");
        $.post("https://races/spawn_ai", JSON.stringify({
            aiName: $("#ai_name").val(),
            vehicle: $("#ai_vehicle").val(),
            ped: $("#ai_ped").val()
        }));
    });

    $("#delete_ai").click(function() {
        if ($("#ai_name").val() == "") {
            $("#registerPanel").hide();
            action = select_action("ai", "https://races/delete_ai", "#ai_name");
            document.getElementById("warning").innerHTML = "Do you really want to delete all AI?";
            $("#confirmPanel").show();
            confirmOpen = true;
        } else {
            action = select_action("ai", "https://races/delete_ai", "#ai_name");
            action()
        };
    });

    $("#list_ai").click(function() {
        $.post("https://races/list_ai");
    });

    $("#grp_access0").change(function() {
        if ("pvt" == $("#grp_access0").val()) {
            document.getElementById("grp_name").innerHTML = pvtGrpNames;
        } else {
            document.getElementById("grp_name").innerHTML = pubGrpNames;
        };
    });

    $("#load_grp").click(function() {
        $.post("https://races/load_grp", JSON.stringify({
            access: $("#grp_access0").val(),
            name: $("#grp_name").val()
        }));
    });

    $("#overwrite_grp").click(function() {
        $("#registerPanel").hide();
        action = select_action("ai_group", "https://races/overwrite_grp", "#grp_name")
        if ($("#grp_access0").val() == "pvt") {
            access = "private"
        } else if ($("#grp_access0").val() == "pub") {
            access = "public"
        };
        document.getElementById("warning").innerHTML = "Do you really want to overwrite " + access + " AI group '" + $("#grp_name").val() + "' ?" 
        $("#confirmPanel").show();
        confirmOpen = true;
    });

    $("#delete_grp").click(function() {
        $("#registerPanel").hide();
        action = select_action("ai_group", "https://races/delete_grp", "#grp_name");
        if ($("#grp_access0").val() == "pvt") {
            access = "private"
        } else if ($("#grp_access0").val() == "pub") {
            access = "public"
        };
        document.getElementById("warning").innerHTML = "Do you really want to delete " + access + " AI group '" + $("#grp_name").val() + "' ?";
        $("#confirmPanel").show();
        confirmOpen = true;
    });

    $("#list_grp").click(function() {
        $.post("https://races/list_grp", JSON.stringify({
            access: $("#grp_access0").val()
        }));
    });

    $("#save_grp").click(function() {
        $.post("https://races/save_grp", JSON.stringify({
            access: $("#grp_access1").val(),
            name: $("#grp_unsaved").val()
        }));
    });

    $("#register_support").click(function() {
        $("#registerPanel").hide();
        $.post("https://races/show", JSON.stringify({
            panel: "support"
        }));
    });

    $("#register_edit").click(function() {
        $("#registerPanel").hide();
        $.post("https://races/show", JSON.stringify({
            panel: "edit"
        }));
    });

    $("#register_close").click(function() {
        $("#registerPanel").hide();
        $.post("https://races/close");
    });

    /* edit panel */
    $("#edit").click(function() {
        $.post("https://races/edit");
    });

    $("#edit_clear").click(function() {
        $.post("https://races/clear");
    });

    $("#edit_reverse").click(function() {
        $.post("https://races/reverse");
    });

    $("#edit_track_access0").change(function() {
        if ("pvt" == $("#edit_track_access0").val()) {
            document.getElementById("edit_name").innerHTML = pvtTrackNames;
        } else {
            document.getElementById("edit_name").innerHTML = pubTrackNames;
        };
    });

    $("#edit_load").click(function() {
        $.post("https://races/load", JSON.stringify({
            access: $("#edit_track_access0").val(),
            trackName: $("#edit_name").val()
        }));
    });

    $("#edit_overwrite").click(function() {
        $("#editPanel").hide();
        action = select_action("track", "https://races/overwrite", "#edit_name");
        if ($("#edit_track_access0").val() == "pvt") {
            access = "private"
        } else if ($("#edit_track_access0").val() == "pub") {
            access = "public"
        };
        document.getElementById("warning").innerHTML = "Do you really want to overwrite " + access + $("#edit_name").val() + "' ?";
        $("#confirmPanel").show();
        confirmOpen = true;
    });

    $("#edit_delete").click(function() {
        $("#editPanel").hide();
        action = select_action("track", "https://races/delete", "#edit_name");
        if ($("#edit_track_access0").val() == "pvt") {
            access = "private"
        } else if ($("#edit_track_access0").val() == "pub") {
            access = "public"
        };
        document.getElementById("warning").innerHTML = "Do you really want to delete " + access + " track '" + $("#edit_name").val() + "' ?";
        $("#confirmPanel").show();
        confirmOpen = true;
    });

    $("#edit_blt").click(function() {
        $.post("https://races/blt", JSON.stringify({
            access: $("#edit_track_access0").val(),
            trackName: $("#edit_name").val()
        }));
    });

    $("#edit_list").click(function() {
        $.post("https://races/list", JSON.stringify({
            access: $("#edit_track_access0").val()
        }));
    });

    $("#edit_save").click(function() {
        $.post("https://races/save", JSON.stringify({
            access: $("#edit_track_access1").val(),
            trackName: $("#edit_unsaved").val()
        }));
    });

    $("#edit_support").click(function() {
        $("#editPanel").hide();
        $.post("https://races/show", JSON.stringify({
            panel: "support"
        }));
    });

    $("#edit_register").click(function() {
        $("#editPanel").hide();
        $.post("https://races/show", JSON.stringify({
            panel: "register"
        }));
    });

    $("#edit_close").click(function() {
        $("#editPanel").hide();
        $.post("https://races/close");
    });

    /* support panel */
    $("#request").click(function() {
        $.post("https://races/request", JSON.stringify({
            role: $("#role").val()
        }));
    });

    $("#support_clear").click(function() {
        $.post("https://races/clear");
    });

    $("#support_track_access").change(function() {
        if ("pvt" == $("#support_track_access").val()) {
            document.getElementById("support_name").innerHTML = pvtTrackNames;
        } else {
            document.getElementById("support_name").innerHTML = pubTrackNames;
        };
    });

    $("#support_load").click(function() {
        $.post("https://races/load", JSON.stringify({
            access: $("#support_track_access").val(),
            trackName: $("#support_name").val()
        }));
    });

    $("#support_blt").click(function() {
        $.post("https://races/blt", JSON.stringify({
            access: $("#support_track_access").val(),
            trackName: $("#support_name").val()
        }));
    });

    $("#support_list").click(function() {
        $.post("https://races/list", JSON.stringify({
            access: $("#support_track_access").val()
        }));
    });

    $("#leave").click(function() {
        $.post("https://races/leave");
    });

    $("#rivals").click(function() {
        $.post("https://races/rivals");
    });

    $("#respawn").click(function() {
        $.post("https://races/respawn");
    });

    $("#results").click(function() {
        $.post("https://races/results");
    });

    $("#spawn").click(function() {
        $.post("https://races/spawn", JSON.stringify({
            vehicle: $("#vehicle").val()
        }));
    });

    $("#lvehicles").click(function() {
        $.post("https://races/lvehicles", JSON.stringify({
            vclass: $("#support_vclass").val()
        }));
    });

    $("#speedo").click(function() {
        $.post("https://races/speedo", JSON.stringify({
            unit: ""
        }));
    });

    $("#change").click(function() {
        $.post("https://races/speedo", JSON.stringify({
            unit: $("#unit").val()
        }));
    });

    $("#funds").click(function() {
        $.post("https://races/funds");
    });

    $("#savep").click(function() {
        $.post("https://races/savep");
    });

    $("#loadp").click(function() {
        $.post("https://races/loadp");
    });

    $("#change_dstyle").click(function() {
        $.post("https://races/change_dstyle", JSON.stringify({
            dstyle: $("#dstyle").val()
        }));
    });

    $("#support_edit").click(function() {
        $("#supportPanel").hide();
        $.post("https://races/show", JSON.stringify({
            panel: "edit"
        }));
    });

    $("#support_register").click(function() {
        $("#supportPanel").hide();
        $.post("https://races/show", JSON.stringify({
            panel: "register"
        }));
    });

    $("#support_close").click(function() {
        $("#supportPanel").hide();
        $.post("https://races/close");
    });

    /* reply panel */
    $("#reply_close").click(function() {
        $("#replyPanel").hide();
        replyOpen = false;
        if ("register" == openPanel) {
            $("#registerPanel").show();
        } else if ("edit" == openPanel) {
            $("#editPanel").show();
        } else if ("support" == openPanel) {
            $("#supportPanel").show();
        };
    });

    /* confirm panel */
    $("#confirm_yes").click(function() {
        $("#confirmPanel").hide();
        action();
    });

    $("#confirm_no").click(function() {
        $("#confirmPanel").hide();
        if ("edit" == openPanel) {
            $("#editPanel").show()
        } else if ("register" == openPanel) {
            $("#registerPanel").show();
        } else if ("support" == openPanel) {
            $("#supportPanel").show()
        };
    });

    document.onkeyup = function(data) {
        if (data.key == "Escape") {
            if (true == replyOpen) {
                $("#replyPanel").hide();
                replyOpen = false;
                if ("register" == openPanel) {
                    $("#registerPanel").show();
                } else if ("edit" == openPanel) {
                    $("#editPanel").show();
                } else if ("support" == openPanel) {
                    $("#supportPanel").show();
                };
            } else if (true == confirmOpen){
                $("#confirmPanel").hide();
                confirmOpen = false;
                if ("register" == openPanel) {
                    $("#registerPanel").show();
                } else if ("edit" == openPanel) {
                    $("#editPanel").show();
                } else if ("support" == openPanel) {
                    $("#supportPanel").show();
                };
            } else {
                $("#supportPanel").hide();
                $("#editPanel").hide();
                $("#registerPanel").hide();
                $.post("https://races/close");
            };
        };
    };
});
