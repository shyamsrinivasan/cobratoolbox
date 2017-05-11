function notShownMets = outputNetworkCytoscape(model,fileBase,rxnList,rxnData,metList,metData,metDegreeThr)
%outputNetworkCytoscape Output a metabolic network in Cytoscape format
%
% notShownMets =
% outputNetworkCytoscape(model,fileBase,rxnList,rxnData,metList,metData,metDegreeThr)
%
%INPUTS
% model         COBRA metabolic network model
% fileBase      Base file name (without extensions) for Cytoscape input
%               files that are generated by the function
%
%OPTIONAL INPUTS
% rxnList       List of reactions that will included in the output
%               (Default = all reactions)
% rxnData       Vector or matrix of data or cell array of strings to output for each
%               reaction in rxnList (Default = empty)
% metList       List of metabolites that will be included in the output
%               (Default = all metabolites)
% metData       Vector or matrix of data or cell array of strings to output
%               for each metabolite in metList (Default = empty)
% metDegreeThr  Maximum degree of metabolites that will be included in the
%               output. Allows filtering out highly connected metabolites
%               such as h2o or atp (Default = no filtering)
%
%OUTPUT
% notShownMets  Metabolites that are not included in the output
%
% Outputs three to five files:
%
% [baseName].sif            Basic network structure file containing
%                           reaction-metabolite and gene-reaction 
%                           (if provided in model) associations
% [baseName]_nodeType.noa   Describes the node types (gene, rxn, met) in the
%                           network
% [baseName]_nodeComp.noa   Describes the compartments for metabolites
% [baseName]_subSys.noa     Describes the subsystems for reactions (if
%                           provided)
% [baseName]_rxnMetData.noa   Reaction and metabolite data (if provided)
%
% Markus Herrgard 9/21/06

if (nargin < 3)
    rxnInd = [1:length(model.rxns)];
    rxnList = model.rxns;
else
    if (isempty(rxnList))
        rxnInd = [1:length(model.rxns)];
        rxnList = model.rxns;
    else
        [isInModel,rxnInd] = ismember(rxnList,model.rxns);
        rxnInd = rxnInd(isInModel);
    end
end

if (nargin < 4)
    rxnData = [];
end

if (nargin < 5)
    metInd = [1:length(model.mets)];
    metList = model.mets;
    selMet = true(length(model.mets),1);
else
    if (isempty(metList))
        metInd = [1:length(model.mets)];
        metList = model.mets;
        selMet = true(length(model.mets),1);
    else
        [isInModel,metInd] = ismember(metList,model.mets);
        metList = metList(isInModel);
        selMet = ismember(model.mets,metList);
    end
end 

if (nargin < 6)
    metData = [];
end

if (nargin < 7)
    allowedMet = true(length(model.mets),1);
    notShownMets = [];
else
    nRxnsMet = sum(model.S' ~= 0)';
    allowedMet = nRxnsMet <= metDegreeThr;
    metsNotAllowed = model.mets(~allowedMet);
    baseMetNames = parseMetNames(model.mets);
    if (~isempty(metsNotAllowed))
        metsNotAllowedBase = parseMetNames(metsNotAllowed);
        allowedMet = ~ismember(baseMetNames,metsNotAllowedBase);
        notShownMets = model.mets(~allowedMet);
    else
        allowedMet = true(length(model.mets),1);
        notShownMets = [];
    end
end

% Open files
fid = fopen([fileBase '.sif'],'w');
fidNodeType = fopen([fileBase '_nodeType.noa'],'w');
fprintf(fidNodeType,'NodeTypes\n');
if (isfield(model,'subSystems'))
    fidSubSys = fopen([fileBase '_subSys.noa'],'w');
    fprintf(fidSubSys,'SubSystems\n');
end
fidEdgeType = fopen([fileBase '_edgeType.noa'],'w');
fprintf(fidEdgeType,'EdgeType\n');

% Print out gene names
if (isfield(model,'genes'))
    for geneNo = 1:length(model.genes)
        fprintf(fidNodeType,'%s = gene\n',model.genes{geneNo});
    end
end

for i = 1:length(rxnList)
    rxnNo = rxnInd(i);
    % Reaction names
    fprintf(fidNodeType,'%s = rxn\n',model.rxns{rxnNo});
    % Subsystems
    if (isfield(model,'subSystems'))
        fprintf(fidSubSys,'%s = %s\n',model.rxns{rxnNo},model.subSystems{rxnNo});
    end
    % Gene-reaction associations
    if (isfield(model,'genes'))
        geneInd = full(find(model.rxnGeneMat(rxnNo,:)));
        for geneNo = 1:length(geneInd)
            fprintf(fid,'%s gra %s\n',model.rxns{rxnNo},model.genes{geneInd(geneNo)});
            fprintf(fidEdgeType,'%s (gra) %s = gra\n',model.rxns{rxnNo},model.genes{geneInd(geneNo)});
        end
    end
    % Reaction associations
    if (model.rev(rxnNo))
        metInd = find(model.S(:,rxnNo) ~= 0 & allowedMet & selMet);
        for j = 1:length(metInd)
            metNo = metInd(j);
            fprintf(fid,'%s rev %s\n',model.rxns{rxnNo},model.mets{metNo});
            fprintf(fidEdgeType,'%s (rev) %s = rev\n',model.rxns{rxnNo},model.mets{metNo});
        end
    else
        metInd = find(model.S(:,rxnNo) < 0 & allowedMet & selMet);
        for j = 1:length(metInd)
            metNo = metInd(j);
            fprintf(fid,'%s dir %s\n',model.mets{metNo},model.rxns{rxnNo});
            fprintf(fidEdgeType,'%s (dir) %s = dir\n',model.mets{metNo},model.rxns{rxnNo});
        end
        metInd = find(model.S(:,rxnNo) > 0 & allowedMet & selMet);
        for j = 1:length(metInd)
            metNo = metInd(j);
            fprintf(fid,'%s dir %s\n',model.rxns{rxnNo},model.mets{metNo});
            fprintf(fidEdgeType,'%s (dir) %s = dir\n',model.rxns{rxnNo},model.mets{metNo});
        end
    end
end
fclose(fid);
fclose(fidEdgeType);
if (isfield(model,'subSystems'))
%     if (isfield(model,'subSystemsMet'))
%         for i = 1:length(model.mets)
%             fprintf(fidSubSys,'%s = %s\n',model.mets{i},model.subSystemsMet{i});
%         end
%     end
    fclose(fidSubSys);
end

% Metabolite names
for metNo = 1:length(model.mets)
    fprintf(fidNodeType,'%s = met\n',model.mets{metNo});
end
fclose(fidNodeType);

% Compartments
[baseMetNames,compSymbols] = parseMetNames(model.mets);
fidComp = fopen([fileBase '_nodeComp.noa'],'w');
fprintf(fidComp,'NodeComp\n');
for i = 1:length(baseMetNames)
    fprintf(fidComp,'%s = %s\n',model.mets{i},compSymbols{i});
end
for i = 1:length(model.rxns)
    rxnCompSymbol = unique(compSymbols(full(model.S(:,i) ~= 0)));
    if (length(rxnCompSymbol) == 1)
        fprintf(fidComp,'%s = %s\n',model.rxns{i},rxnCompSymbol{1});
    else
        fprintf(fidComp,'%s = t\n',model.rxns{i});
    end
end
fclose(fidComp);

% Reaction data
if (~isempty(metData))
    fidData = fopen([fileBase '_rxnMetData.noa'],'w');
    [nMets,nSets] = size(metData);
    if (nSets == 1)
        fprintf(fidData,'rxnMetData\n');
        for i = 1:nMets
            if (iscell(metData))
                fprintf(fidData,'%s = %s\n',metList{i},metData{i});
            else
                fprintf(fidData,'%s = %f\n',metList{i},metData(i));
            end
        end
    else
        fprintf(fidData,'ID\tID\t');
        for j = 1:nSets
            fprintf(fidData,'set%d\t',j);
        end
        fprintf(fidData,'\n');
        for i = 1:nMets
            fprintf(fidData,'%s\t%s\t',metList{i},metList{i});
            for j = 1:nSets
                if (iscell(metData))
                    fprintf(fidData,'%s\t',metData{i,j});
                else
                    fprintf(fidData,'%f\t',metData(i,j));
                end
            end
            fprintf(fidData,'\n');
        end 
    end
    if (isempty(rxnData))
        fclose(fidData);
    end
end

% Reaction data
if (~isempty(rxnData))
    [nRxns,nSets] = size(rxnData);
    if (isempty(metData))
        fidData = fopen([fileBase '_rxnMetData.noa'],'w');
        if (nSets == 1)
            fprintf(fidData,'rxnMetData\n');
        else
            fprintf(fidData,'ID\tID\t');
            for j = 1:nSets
                fprintf(fidData,'set%d\t',j);
            end
            fprintf(fidData,'\n');
        end
    end
    
    if (nSets == 1)
        for i = 1:nRxns
            if (iscell(rxnData))
                fprintf(fidData,'%s = %s\n',rxnList{i},rxnData{i});
            else
                fprintf(fidData,'%s = %f\n',rxnList{i},rxnData(i));
            end
        end
    else
        for i = 1:nRxns
            fprintf(fidData,'%s\t%s\t',rxnList{i},rxnList{i});
            for j = 1:nSets
                if (iscell(rxnData))
                    fprintf(fidData,'%s\t',rxnData{i,j});
                else
                    fprintf(fidData,'%f\t',rxnData(i,j));
                end
            end
            fprintf(fidData,'\n');
        end
    end
    fclose(fidData);
end