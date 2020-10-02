import React from 'react';

export interface DataViewProps {
    id: string
    name: string,
}

type DataViewState = {
    id: string,
    name: string,
    nodes: DataNodeListState,
}

type DataNodeListState = {
    vars: DataNodeState[],
    pars: DataNodeState[],
}

type DataNodeState = {
    name: string,
    item_name: string,
    comp_name: string,
}

export default class ExplorerDataView extends React.Component<DataViewProps, DataViewState> {
    static defaultProps = {
        id: "",
        name: ""
    };

    constructor(props: DataViewProps) {
        super(props);
        this.state ={
            id: props.id,
            name: props.name,
            nodes: {
                vars: [],
                pars: [],
            },
        }
        global["setData"] = this.setData;
    }

    setData = (nodeInfo:DataNodeListState) => {
        this.setState({nodes: nodeInfo});
    }

    renderNode = (nodeState: DataNodeState) => {
        return (<li onClick={(event) => {
            event.preventDefault();
            global["sendMessageToJulia"]({
                cmd: 'display_spec',
                comp_name: nodeState.comp_name,
                item_name: nodeState.item_name
            })
        }}>{nodeState.name}</li>);
    }

    render = () => {
        const renderVal = (
        <div className="ExplorerDataView">
            <h4>{this.state.name}</h4>
            <h6>Variables</h6>
            <ul>
                {this.state.nodes && this.state.nodes.vars ? this.state.nodes.vars.map((n) => this.renderNode(n)) : null}
            </ul>
            <h6>Parameters</h6>
            <ul>
                {this.state.nodes && this.state.nodes.pars ? this.state.nodes.pars.map((n) => this.renderNode(n)) : null}
            </ul>
        </div>
        );
        return renderVal;
    };
}