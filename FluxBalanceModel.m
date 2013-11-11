classdef FluxBalanceModel
    %FluxBalanceModel: Holds a flux balance model and
    % does all sorts of usefull operations on it, like searching
    % for reactions, plotting network diagrams, etc
    
    % properties
    properties (SetAccess = protected)
        model   = [];
        results = [];
    end
    
    methods
        % constructor: creates a new instance of FluxBalanceModel
        % from a previously loaded model file (e.g. pao.mat)
        function tsd = FluxBalanceModel(model)
            % add directories to path if working with graphviz
            %             setenv('PATH', [getenv('PATH') ':/usr/local/bin']);
            %             addpath(genpath('graphViz4Matlab'));
            workingDirectory = pwd;
            cd('/Library/gurobi550/mac64/matlab');
            gurobi_setup;
            cd(workingDirectory);
            % import the model
            tsd.model = model;
        end
        
        % writes out a summary of the reaction n
        function [] = queryReaction(tsd, n)
            name = tsd.model.rxnNames{n};
            
            fprintf('%s:\n', name);
            
            metaboliteIndices = find(tsd.model.S(:, n) ~= 0);
            stoichiometry     = full(tsd.model.S(metaboliteIndices, n));
            metaboliteNames   = tsd.model.metNames(metaboliteIndices);
            
            metsConsumed = find(stoichiometry < 0);
            for i = 1:length(metsConsumed)
                if i > 1
                    fprintf(' + ');
                end
                m = metsConsumed(i);
                fprintf('%d %s', -stoichiometry(m), metaboliteNames{m});
            end
            
            fprintf(' -> ');
            
            
            metsProduced = find(stoichiometry > 0);
            for i = 1:length(metsProduced)
                if i > 1
                    fprintf(' + ');
                end
                m = metsProduced(i);
                fprintf('%d %s', stoichiometry(m), metaboliteNames{m});
            end
            
            fprintf('\n');
        end
        
        % serches for metabolites which contain the string
        % search is case insensitive
        function metIndices = findMetabolite(tsd, metString)
            
            indices = strfind(lower(tsd.model.metNames), lower(metString));
            metIndices = find(~cellfun(@isempty, indices));
            
            % print out
            fprintf('\nMetabolites that match ''%s'':\n', metString);
            for i = 1:length(metIndices)
                m = metIndices(i);
                fprintf('%d: %s\n', m, tsd.model.metNames{m});
            end
            fprintf('\n');
        end;
        
        % find all the reactions that involve metabolite n
        function rxnIndices = findRactionsWithMetabolite(tsd, n)
            rxnIndices = find(tsd.model.S(n, :));
        end
        
        
        % find all the reactions that involve metabolites
        % matching metString
        function rxnIndices = queryRactionsWithMetabolite(tsd, metString)
            fprintf('\nReactions involving ''%s'':\n', metString);
            metIndices = tsd.findMetabolite( metString);
            for i = 1:length(metIndices)
                fprintf('METABOLITE %s:', tsd.model.metNames{metIndices(i)});
                rxnIndices = tsd.findRactionsWithMetabolite(metIndices(i));
                for j = 1:length(rxnIndices)
                    tsd.queryReaction(rxnIndices(j));
                    fprintf('\n');
                end
                fprintf('\n');
            end
        end
        
        % run gurobi with present version of the model
        function tsd = runGurobi(tsd)
            model.A = sparse(tsd.model.S);
            model.obj = tsd.model.c;
            model.rhs = tsd.model.b;
            model.sense = char(ones(length(tsd.model.mets),1).*'=');
            model.vtype = char(ones(length(tsd.model.rxns),1).*'C'); % continuous vars
            model.modelsense = 'max'; % maximize
            model.lb = tsd.model.lb;
            model.ub = tsd.model.ub;
            
            clear params;
            params.outputflag = 0;
            params.resultfile = 'garbage.lp';
            
            tsd.results = gurobi(model, params);
            
            disp(tsd.results)
            
        end
        

        % plot the results form the gurobi run
        function bg = plotFluxes(tsd)
            if isempty(tsd.results)
                error('No results yet. Execture ''runGurobi'' first')
            end
            % find all the ractions with non zero fluxes
            rxns = find(tsd.results.x ~= 0);
            % find all the metabolites involved in these reactions
            mets = find(sum(tsd.model.S(:, rxns), 2) > 0);
            % make the new matrix
            matrix = tsd.model.S(mets, rxns);
            % calculate fluxes
            fluxMatrix = full(matrix) .*...
                repmat(full(tsd.results.x(rxns)'), [length(mets), 1]);
            % create matrix of mets vs mets
            fluxNet = zeros(length(mets));
            for i = 1:length(rxns)
                flux = fluxMatrix(:, i);
                netFlux = sum(flux(flux>0));
                metsConsumed = find(flux<0);
                metsProduced = find(flux>0);
                for j = 1:length(metsConsumed)
                    for k = 1:length(metsProduced)
                        % add flux from this reaction
                        f = flux(metsProduced(k))/netFlux;
                        fluxNet(metsProduced(k), metsConsumed(j)) =...
                            fluxNet(metsProduced(k), metsConsumed(j)) -...
                            flux(metsConsumed(j)) * f;
                    end
                end
            end
            % graphViz code
            %             nodeColors = cell(1, length(mets));
            %             biomass = tsd.findMetabolite('biomass');
            %             glucose = tsd.findMetabolite('glucose');
            %             glycerol = tsd.findMetabolite('glycerol');
            %             for i = 1:length(mets)
            %                 nodeColors{i} = 'w';
            %                 if ismember(mets(i), biomass)
            %                     nodeColors{i} = 'r';
            %                 end
            %                 if ismember(mets(i), glucose)
            %                     nodeColors{i} = 'g';
            %                 end
            %                 if ismember(mets(i), glycerol)
            %                     nodeColors{i} = 'b';
            %                 end
            %             end
            %             edgeColors = {'g','b','r','c'}
            %             graphViz4Matlab('-adjMat',fluxNet,...
            %                 '-nodeLabels',tsd.model.metNames(mets),...
            %                 '-layout',Gvizlayout,...
            %                 '-nodeColors',nodeColors,...
            %                 '-edgeColors', edgeColors);
            
            %use this to draw with matlab code
            bg = biograph(fluxNet, tsd.model.metNames(mets));
            nodes = get(bg, 'Nodes');
            % set the biomass to red
            [~, i, ~] = intersect(mets, tsd.findMetabolite('biomass'));
            set(nodes(i), 'Color', [1 0 0]);
            % set the glucose to blue
            [~, i, ~] = intersect(mets, tsd.findMetabolite('glucose'));
            set(nodes(i), 'Color', [0 0 1]);
            view(bg);
        end
        
        
    end % END OF METHODS
    
end

