# Tutorial 1: Explore an Existing Model

This tutorial walks through the steps to download, run, and view the output of an existing model.  There are several existing models public on Github, and for the purposes of this tutorial we will use [The Climate Framework for Uncertainty, Negotiation and Distribution (FUND)](http://www.fund-model.org), available on Github [here](https://github.com/fund-model/fund).

Working through the following tutorial will require:

- [Julia v1.0.0](https://julialang.org/downloads/) or higher
- [Mimi v0.6.0](https://github.com/anthofflab/Mimi.jl) 
- [Git](https://git-scm.com/downloads) and [Github](https://github.com)

If you have not yet prepared these, go back to the main tutorial page and follow the instructions for their download.  

## Step 1. Download FUND

The first step in this process is downloading the FUND model.  Open a Julia REPL (here done with the alias command `Julia`) and navigate to the folder where you would like to download FUND.

```
Julia 
cd("directory")
```

Next, clone the existing FUND repository from Github and enter the new repository.
```
git clone https://github.com/fund-model/fund.git
cd("fund")
```

You have now successfully downloaded FUND to your local machine.

## Step 1. Run FUND

The next step is to run FUND.  If you wish to first get more aquainted with the model itself, take a look at the provided online documentation.  
