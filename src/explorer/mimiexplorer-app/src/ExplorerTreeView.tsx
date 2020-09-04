import React from 'react';
import { TreeView, TreeItem } from '@material-ui/lab';
import { ExpandMore, ChevronRight } from "@material-ui/icons";

export interface TreeViewProps {
    name: string
}

type TreeNodeState = {
    name: string,
    children: Array<TreeNodeState>
}
  
export default class ExplorerTreeView extends React.Component<TreeViewProps, TreeNodeState> {

    static defaultProps = {
        name: "",
    }

    constructor(props: TreeViewProps) {
        super(props);
        this.state ={
            name: props.name,
            children: new Array<TreeNodeState>()
        }
        global["setTreeChildren"] = this.setTreeChildren;
    }

    setTreeChildren = (childrenInfo:Array<TreeNodeState>) => {
        console.dir(childrenInfo)
        this.setState({children: childrenInfo});
    }

    renderTree = (node:TreeNodeState) => {
        console.dir(node.name);
        return (<TreeItem key={node.name} nodeId={node.name} label={node.name}>
                     {node.children ? node.children.map((n) => this.renderTree(n)) : null}
                 </TreeItem>);
    }

    render = () => {
        const renderVal = (<TreeView
            className={"classes.root"}
            defaultCollapseIcon={<ExpandMore />}
            defaultExpanded={["root"]}
            defaultExpandIcon={<ChevronRight />}
        >
            {this.renderTree(this.state)}
        </TreeView>);

        // console.dir(renderVal)

        return renderVal;
    };
}

  