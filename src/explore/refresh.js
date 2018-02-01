// Mimi UI

function refresh() {
    
    // Loop over the things that we want to show in the list, add
    // one button for each element as a child to the variablelist
    // DIV
    for (var i in speclist) {

        var newButton = document.createElement("button");
        newButton.setAttribute("class", "tablinks");

        newButton.setAttribute("onclick", `openVar(event, '${i}')`);
        newButton.appendChild(document.createTextNode(speclist[i]["name"]));
        document.getElementById("variablelist").appendChild(newButton);
            
    }
}

// This is the event handler that gets called whenever someone
// clicks one of the buttons.
function openVar(evt, index) {
    
    // Plot the spec
    var spec = speclist[index]["VLspec"];
    
    vegaEmbed("#vis", spec, { actions: false });
}
