import React from 'react';
import { TreeView, TreeItem } from '@material-ui/lab';
import { ExpandMore, ChevronRight } from "@material-ui/icons";

export interface TreeViewProps {
    id: string,
    name: string
}

type TreeNodeState = {
    id: string,
    name: string,
    children: Array<TreeNodeState>
}

type ChildrenInfo = {
    name: string,
    item_name: string,
    comp_name: string
}
  
export default class ExplorerTreeView extends React.Component<TreeViewProps, TreeNodeState> {

    static defaultProps = {
        id: "",
        name: "",
        children: new Array<TreeNodeState>()
    }

    constructor(props: TreeViewProps) {
        super(props);
        this.state ={
            id: props.id,
            name: props.name,
            children: new Array<TreeNodeState>()
        }
        global["setTreeChildren"] = this.setTreeChildren;
    }

    renderTree = (nodes:Array<TreeNodeState>) => {
        if (nodes === null || !Array.isArray(nodes) || nodes.length === 0) {
            return <div></div>;
        }
        return nodes.map(node => {
            return (<TreeItem key={node.id} nodeId={node.id} label={node.name}>
                {this.renderTree(node.children)}
            </TreeItem>);
        });
    }

    setTreeChildren = (childrenInfo:Array<ChildrenInfo>) => {
        return null;
    }

    render = () => {
        return <TreeView
            className={"classes.root"}
            defaultCollapseIcon={<ExpandMore />}
            defaultExpanded={["root"]}
            defaultExpandIcon={<ChevronRight />}
        >
            {this.renderTree(this.state.children)}
        </TreeView>
    };
}

  