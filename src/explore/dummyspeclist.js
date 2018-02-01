// Mimi UI

var speclist = 
[
    {
        name: "Var 1",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple bar chart for regional data.",
            "title": "Var 1",
            "data": {
                "values": [
                    { "Region": "A", "Quantity": 28 }, { "Region": "B", "Quantity": 55 }, { "Region": "C", "Quantity": 43 },
                    { "Region": "D", "Quantity": 91 }, { "Region": "E", "Quantity": 81 }, { "Region": "F", "Quantity": 53 },
                    { "Region": "G", "Quantity": 19 }, { "Region": "H", "Quantity": 87 }, { "Region": "I", "Quantity": 52 }
                ]
            },
            "mark": "bar",
            "encoding": {
                "x": { "field": "Region", "type": "ordinal" },
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    },

    {
        name:  "Var 2",
        VLspec: {
                "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple line graph for time series.",
            "title": "Var 2",
            "data": {
                "values": [
                    { "Time": 1, "Quantity": 28 }, { "Time": 2, "Quantity": 55 }, { "Time": 3, "Quantity": 43 },
                    { "Time": 4, "Quantity": 91 }, { "Time": 5, "Quantity": 81 }, { "Time": 6, "Quantity": 53 },
                    { "Time": 7, "Quantity": 19 }, { "Time": 8, "Quantity": 87 }, { "Time": 9, "Quantity": 52 }
                ]
            },
            "mark": "line",
            "encoding": {
                "x": { "field": "Time", "type": "temporal", "Axis" : {"format": "%Y}}" }},
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    },

    {
        name: "Var 3",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "line graph for time series for several regions",
            "title": "Var 3",
            "data": {
                "values": [
                    { "Time": 1, "Quantity": 28, "symbol": "A"}, { "Time": 2, "Quantity": 55, "symbol": "A" }, { "Time": 3, "Quantity": 43, "symbol": "A" },
                    { "Time": 4, "Quantity": 91, "symbol": "A" }, { "Time": 5, "Quantity": 81, "symbol": "A" }, { "Time": 6, "Quantity": 53, "symbol": "A" },
                    { "Time": 7, "Quantity": 19, "symbol": "A"}, { "Time": 8, "Quantity": 87, "symbol": "A" }, { "Time": 9, "Quantity": 52, "symbol": "A" },
                
                    { "Time": 1, "Quantity": 120, "symbol": "B"}, { "Time": 2, "Quantity": 65, "symbol": "B" }, { "Time": 3, "Quantity": 67, "symbol": "A" },
                    { "Time": 4, "Quantity": 52, "symbol": "B" }, { "Time": 5, "Quantity": 91, "symbol": "B" }, { "Time": 6, "Quantity": 73, "symbol": "B" },
                    { "Time": 7, "Quantity": 89, "symbol": "B"}, { "Time": 8, "Quantity": 107, "symbol": "B" }, { "Time": 9, "Quantity": 83, "symbol": "B" }    
                ]
            },
            "mark": "line",
            "encoding": {
                "x": {"field": "Time", "type": "temporal"},
                "y": {"field": "Quantity", "type": "quantitative"},
                "color": {"field": "symbol", "type": "nominal"}
            },
            "width": 400,
            "height": 400,
        }
    },

    {
        name:  "Var 4", 
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.json",
            "description": "stacked line graph for time series for several regions",
            "title": "Var 4",
            
            "data": {

                "values": [
                    {'count': 1532, 'date': '2016-07-05', 'label': 'group2'},
                    {'count': 4712, 'date': '2016-07-05', 'label': 'group1'},
                    {'count': 1736, 'date': '2016-07-06', 'label': 'group2'},
                    {'count': 4970, 'date': '2016-07-06', 'label': 'group1'},
                    {'count': 1960, 'date': '2016-07-07', 'label': 'group2'},
                    {'count': 5248, 'date': '2016-07-07', 'label': 'group1'},
                    {'count': 2002, 'date': '2016-07-08', 'label': 'group2'},
                    {'count': 5360, 'date': '2016-07-08', 'label': 'group1'},
                    {'count': 1969, 'date': '2016-07-09', 'label': 'group2'},
                    {'count': 4548, 'date': '2016-07-09', 'label': 'group1'},
                    {'count': 1931, 'date': '2016-07-10', 'label': 'group2'},
                    {'count': 4631, 'date': '2016-07-10', 'label': 'group1'},
                    {'count': 2316, 'date': '2016-07-11', 'label': 'group2'},
                    {'count': 5817, 'date': '2016-07-11', 'label': 'group1'}
                ]
            },

            "mark": "area",
            "encoding": {
                "y": {"aggregate": "sum", "field": "count", "type": "quantitative"},
                "x": {"field": "date", "type": "temporal", "timeUnit": "yearmonthdate"},
            "color": {"field":"label", "type":"nominal", "scale": {"range": ["#e6aa06", "#1f77b4"]}}
            },
            "config": {"mark": {"stacked": "normalize"}
        },
        "width": 400,
        "height": 400,
    }
},

    {
        name: "Var 5",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple bar chart for regional data.",
            "title": "Var 1",
            "data": {
                "values": [
                    { "Region": "A", "Quantity": 28 }, { "Region": "B", "Quantity": 55 }, { "Region": "C", "Quantity": 43 },
                    { "Region": "D", "Quantity": 91 }, { "Region": "E", "Quantity": 81 }, { "Region": "F", "Quantity": 53 },
                    { "Region": "G", "Quantity": 19 }, { "Region": "H", "Quantity": 87 }, { "Region": "I", "Quantity": 52 }
                ]
            },
            "mark": "bar",
            "encoding": {
                "x": { "field": "Region", "type": "ordinal" },
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    },
    {
        name: "Var 6",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple bar chart for regional data.",
            "title": "Var 1",
            "data": {
                "values": [
                    { "Region": "A", "Quantity": 28 }, { "Region": "B", "Quantity": 55 }, { "Region": "C", "Quantity": 43 },
                    { "Region": "D", "Quantity": 91 }, { "Region": "E", "Quantity": 81 }, { "Region": "F", "Quantity": 53 },
                    { "Region": "G", "Quantity": 19 }, { "Region": "H", "Quantity": 87 }, { "Region": "I", "Quantity": 52 }
                ]
            },
            "mark": "bar",
            "encoding": {
                "x": { "field": "Region", "type": "ordinal" },
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    },
    {
        name: "Var 7",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple bar chart for regional data.",
            "title": "Var 1",
            "data": {
                "values": [
                    { "Region": "A", "Quantity": 28 }, { "Region": "B", "Quantity": 55 }, { "Region": "C", "Quantity": 43 },
                    { "Region": "D", "Quantity": 91 }, { "Region": "E", "Quantity": 81 }, { "Region": "F", "Quantity": 53 },
                    { "Region": "G", "Quantity": 19 }, { "Region": "H", "Quantity": 87 }, { "Region": "I", "Quantity": 52 }
                ]
            },
            "mark": "bar",
            "encoding": {
                "x": { "field": "Region", "type": "ordinal" },
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    },
    {
        name: "Var 8",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple bar chart for regional data.",
            "title": "Var 1",
            "data": {
                "values": [
                    { "Region": "A", "Quantity": 28 }, { "Region": "B", "Quantity": 55 }, { "Region": "C", "Quantity": 43 },
                    { "Region": "D", "Quantity": 91 }, { "Region": "E", "Quantity": 81 }, { "Region": "F", "Quantity": 53 },
                    { "Region": "G", "Quantity": 19 }, { "Region": "H", "Quantity": 87 }, { "Region": "I", "Quantity": 52 }
                ]
            },
            "mark": "bar",
            "encoding": {
                "x": { "field": "Region", "type": "ordinal" },
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    },
    {
        name: "Var 9",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple bar chart for regional data.",
            "title": "Var 1",
            "data": {
                "values": [
                    { "Region": "A", "Quantity": 28 }, { "Region": "B", "Quantity": 55 }, { "Region": "C", "Quantity": 43 },
                    { "Region": "D", "Quantity": 91 }, { "Region": "E", "Quantity": 81 }, { "Region": "F", "Quantity": 53 },
                    { "Region": "G", "Quantity": 19 }, { "Region": "H", "Quantity": 87 }, { "Region": "I", "Quantity": 52 }
                ]
            },
            "mark": "bar",
            "encoding": {
                "x": { "field": "Region", "type": "ordinal" },
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    },
    {
        name: "Var 10",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "line graph for time series for several regions",
            "title": "Var 3",
            "data": {
                "values": [
                    { "Time": 1, "Quantity": 28, "symbol": "A"}, { "Time": 2, "Quantity": 55, "symbol": "A" }, { "Time": 3, "Quantity": 43, "symbol": "A" },
                    { "Time": 4, "Quantity": 91, "symbol": "A" }, { "Time": 5, "Quantity": 81, "symbol": "A" }, { "Time": 6, "Quantity": 53, "symbol": "A" },
                    { "Time": 7, "Quantity": 19, "symbol": "A"}, { "Time": 8, "Quantity": 87, "symbol": "A" }, { "Time": 9, "Quantity": 52, "symbol": "A" },
                
                    { "Time": 1, "Quantity": 120, "symbol": "B"}, { "Time": 2, "Quantity": 65, "symbol": "B" }, { "Time": 3, "Quantity": 67, "symbol": "A" },
                    { "Time": 4, "Quantity": 52, "symbol": "B" }, { "Time": 5, "Quantity": 91, "symbol": "B" }, { "Time": 6, "Quantity": 73, "symbol": "B" },
                    { "Time": 7, "Quantity": 89, "symbol": "B"}, { "Time": 8, "Quantity": 107, "symbol": "B" }, { "Time": 9, "Quantity": 83, "symbol": "B" }    
                ]
            },
            "mark": "line",
            "encoding": {
                "x": {"field": "Time", "type": "temporal"},
                "y": {"field": "Quantity", "type": "quantitative"},
                "color": {"field": "symbol", "type": "nominal"}
            },
            "width": 400,
            "height": 400,
        }
    },
    {
        name: "Var 11",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple bar chart for regional data.",
            "title": "Var 1",
            "data": {
                "values": [
                    { "Region": "A", "Quantity": 28 }, { "Region": "B", "Quantity": 55 }, { "Region": "C", "Quantity": 43 },
                    { "Region": "D", "Quantity": 91 }, { "Region": "E", "Quantity": 81 }, { "Region": "F", "Quantity": 53 },
                    { "Region": "G", "Quantity": 19 }, { "Region": "H", "Quantity": 87 }, { "Region": "I", "Quantity": 52 }
                ]
            },
            "mark": "bar",
            "encoding": {
                "x": { "field": "Region", "type": "ordinal" },
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    },
    {
        name: "Var 12",
        VLspec: {
            "$schema": "https://vega.github.io/schema/vega-lite/v2.0.json",
            "description": "A simple bar chart for regional data.",
            "title": "Var 1",
            "data": {
                "values": [
                    { "Region": "A", "Quantity": 28 }, { "Region": "B", "Quantity": 55 }, { "Region": "C", "Quantity": 43 },
                    { "Region": "D", "Quantity": 91 }, { "Region": "E", "Quantity": 81 }, { "Region": "F", "Quantity": 53 },
                    { "Region": "G", "Quantity": 19 }, { "Region": "H", "Quantity": 87 }, { "Region": "I", "Quantity": 52 }
                ]
            },
            "mark": "bar",
            "encoding": {
                "x": { "field": "Region", "type": "ordinal" },
                "y": { "field": "Quantity", "type": "quantitative" }
            },
            "width": 400,
            "height": 400,
        }
    }
]

