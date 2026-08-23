const fs = require('node:fs/promises');

// Mimi UI

function refresh(menu_item_list) {
    
    // Loop over the things that we want to show in the list, add
    // one button for each element as a child to the variablelist div

    var element = document.getElementById("variablelist");

    for (var i in menu_item_list) {

        var newButton = document.createElement("button");
        newButton.setAttribute("class", "tab");
        
        // Set onclick for button
        newButton.onclick = (function() {

            var comp_name = menu_item_list[i]["comp_name"]
            var item_name = menu_item_list[i]["item_name"]

            return function() {
                sendMessageToJulia({cmd: 'display_spec', comp_name: comp_name, item_name: item_name})
            }

        })()

        newButton.appendChild(document.createTextNode(menu_item_list[i]["name"]));
        element.appendChild(newButton);
    }
}

function display(spec) {
    const loader = {
        load: async function(uri, options) {
            const parsedUri = new URL(uri)
            if (parsedUri.protocol!='file') {
                throw new Error('Only file URIs are allowed in the vega-lite spec.');
            }

            return await fs.readFile(new URL(uri))
        },
    }
    vegaEmbed("#vis", spec["VLspec"], {actions: false, loader: loader});
}
