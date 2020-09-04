import React from 'react';

export interface VariableViewProps {
    id: string
    name: string,
}

type VariableViewState = {
    id: string,
    name: string,
    nodes: VariableNodeState[],
}

type VariableNodeState = {
    name: string,
    item_name: string,
    comp_name: string,
}

export default class ExplorerVariableView extends React.Component<VariableViewProps, VariableViewState> {
    static defaultProps = {
        id: "",
        name: ""
    };

    constructor(props: VariableViewProps) {
        super(props);
        this.state ={
            id: props.id,
            name: props.name,
            nodes: [],
        }
        global["setVariables"] = this.setVariables;
    }

    setVariables = (nodeInfo:VariableNodeState[]) => {
        this.setState({nodes: nodeInfo});
    }

    renderNode = (nodeState: VariableNodeState) => {
        console.dir(nodeState.name)
        console.dir(nodeState.item_name)
        console.dir(nodeState.comp_name)

        const renderVal = <li>{nodeState.name}</li>;
        console.dir(renderVal);

        return renderVal;
    }

    render = () => {
        const renderVal = (
        <div>
            <h4>{this.state.name}</h4>
            <ul>
                {this.state.nodes ? this.state.nodes.map((n) => this.renderNode(n)) : null}
            </ul>
        </div>
        );

        console.dir(renderVal)

        return renderVal;
    };
}