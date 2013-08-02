classdef FluxBalanceModel
    %FluxBalanceModel: Holds a flux balance model and
    % does all sorts of usefull operations on it, like searching
    % for reactions, plotting network diagrams, etc
    
    % properties
    properties (SetAccess = protected)
        model = [];
    end
    
    methods
        % constructor: creates a new instance of FluxBalanceModel
        % from a previously loaded model file (e.g. pao.mat)
        function tsd = FluxBalanceModel(model)
            % add directories to path
            addpath(genpath('/usr/local/bin'));
            addpath(genpath('graphViz4Matlab'));
            workingDirectory = pwd;
            cd('/Library/gurobi550/mac64/matlab');
            gurobi_setup;
            cd(workingDirectory);
            % import the model
            tsd.model = model;
        end
        
        % writes out a summary of the reaction n
        function [] = queryReaction(tsd, n)
            fprintf('\n');
            
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
            
            fprintf('\n\n');
            
            
            
        end
        
        
    end
    
end

