function aux_plotPathlineMetricKinematicsLobes_integrated(QS, m2plot, ...
    fn, fn_withH, lobes, tps, divv, H2vn, HH, lobeYlabels, ...
    avgString, Hsz, overwrite)
%aux_plotMetricKinematicsFolds_2panel_withH
%(fn, divv, H2vn, HH, width, foldYlabels)
%
% Parameters
% ----------
% fn : str
%   path to output figure filename
% divv : 
%
% NPMitchell 2020

% Plot all lobes on one axis
if ~exist(fn, 'file') || overwrite 
    close all
    set(gcf, 'visible', 'off')
    for jj = 1:length(lobes)
        % div(v), H*2*vn, gdot
        switch lower(m2plot)
            case 'gdot'
                gdj = mean(divv(:, lobes{jj}) - H2vn(:, lobes{jj}), 2) ;
            case 'divv'
                gdj = mean(divv(:, lobes{jj}), 2) ;
            case 'h2vn'
                gdj = mean(H2vn(:, lobes{jj}), 2) ;
        end

        % Take cumulative product marching forward from t0
        gpj_pos = cumprod(1 + gdj(tps > eps)) ;
        gpj_neg = flipud(cumprod(flipud(1 ./ (1 + gdj(tps < eps))))) ;
        gpj = cat(1, gpj_neg, gpj_pos) ;               

        % Plot this fold
        plot(tps, gpj, '.-', 'Color', QS.plotting.colors(jj, :))
        hold on;
    end    

    % Title and labels
    sgtitle(['Tissue dilation in lobes, ', avgString, ...
        ', $\frac{1}{2}\mathrm{Tr} \left[g^{-1} \dot{g}\right]$'], ...
        'Interpreter', 'Latex')
    legend(lobeYlabels, 'Interpreter', 'Latex', 'location', 'eastOutside')  
    drawnow
    xlabel(['time [' QS.timeUnits ']'], 'Interpreter', 'Latex')
    switch lower(m2plot)
        case 'gdot'
            ylabel('$\Pi\big(1+$d$t\, \frac{1}{2}\mathrm{Tr} \left[g^{-1} \dot{g}\right]\big)$', ...
                    'Interpreter', 'Latex')
        case 'divv'
            ylabel('$\Pi\big(1+$d$t\,  \nabla \cdot \mathbf{v}_{\parallel} \big)$', ...
                    'Interpreter', 'Latex')
        case 'h2vn'
            ylabel('$\Pi\big(1+$d$t\, 2H v_n \big)$', ...
                    'Interpreter', 'Latex')
    end
    % Save figure
    disp(['Saving figure: ', fn])
    saveas(gcf, fn)
end

%% Same plot but add mean curvature as second panel
if ~exist(fn_withH, 'file') || overwrite 
    close all
    subplot(2, 1, 1)
    % Each fold is valley+/- width
    for jj = 1:length(lobes)                
        % div(v), H*2*vn, gdot
        gdj = mean(divv(:, lobes{jj}) - H2vn(:, lobes{jj}), 2) ;

        % Take cumulative product marching forward from t0
        gpj_pos = cumprod(1 + gdj(tps > eps)) ;
        gpj_neg = flipud(cumprod(flipud(1 ./ (1 + gdj(tps < eps))))) ;
        gpj = cat(1, gpj_neg, gpj_pos) ;               

        % Plot this fold
        plot(tps, gpj, '.-', 'Color', QS.plotting.colors(jj, :))
        hold on;
    end    

    % Title and labels
    sgtitle(['Tissue dilation in lobes, ', avgString], ...
        'Interpreter', 'Latex')
    legend(lobeYlabels, 'Interpreter', 'Latex', 'location', 'eastOutside')  
    drawnow
    xlabel(['time [' QS.timeUnits ']'], 'Interpreter', 'Latex')
    ylabel('$\Pi\big(1+$d$t\, \frac{1}{2}\mathrm{Tr} \left[g^{-1} \dot{g}\right]\big)$', ...
        'Interpreter', 'Latex')
    pos = get(gca, 'pos') ;

    % SECOND PANEL -- mean curvature
    subplot(2, 1, 2)
    lobeHlabels = {} ;
    for jj = 1:length(lobes)

        % Mark the instantaneous mean curvature
        Hj = mean(HH(:, lobes{jj}), 2) ;
        scatter(tps(Hj>0), Hj(Hj>0), Hsz, 'filled', 's', ...
            'markeredgecolor', QS.plotting.colors(jj, :), ...
            'markerfacecolor', QS.plotting.colors(jj, :))
        hold on
        scatter(tps(Hj<0), Hj(Hj<0), Hsz, 's', ...
            'markeredgecolor', QS.plotting.colors(jj, :))

        if any(Hj > 0)
            lobeHlabels{length(lobeHlabels) + 1} = ...
                ['$H>0$, ' lobeYlabels{jj} ] ;
        end
        if any(Hj < 0)
            lobeHlabels{length(lobeHlabels) + 1} = ...
                ['$H<0$, ' lobeYlabels{jj} ] ;
        end
        % Identify time(s) at which H changes sign
        crossH{jj} = find(diff(sign(Hj)) < 0) ;
    end
    % Add indicators for changing sign
    Hlims = get(gca, 'ylim') ;
    Hmin = Hlims(1) ;
    Hmax = Hlims(2) ;
    crossH_exist = false ;
    for jj = 1:length(lobes)
        for kk = 1:length(crossH{jj})
            subplot(2, 1, 1)
            plot(tps(crossH{jj}(kk))*[1,1], [ymin, ymax], '--', ...
                'color', QS.plotting.colors(jj, :), ...
                'HandleVisibility','off') ;
            subplot(2, 1, 2)
            plot(tps(crossH{jj}(kk))*[1,1], [Hmin, Hmax], '--', ...
                'color', QS.plotting.colors(jj, :), ...
                'HandleVisibility','off') ;
            crossH_exist = true ;
        end
    end
    if crossH_exist
        plot(tps, 0*tps, 'k--', 'HandleVisibility','off') ;
    end
    legend(lobeHlabels, 'Interpreter', 'Latex', 'location', 'eastOutside')
    xlabel(['time [' QS.timeUnits ']'], 'Interpreter', 'Latex')
    ylabel('lobe curvature, $H$', 'Interpreter', 'Latex')
    pos2 = get(gca, 'pos') ;
    set(gca, 'pos', [pos(1) pos2(2) pos(3) pos(4)]) ;

    % Save figure with mean curvature
    disp(['Saving figure: ', fn_withH])
    saveas(gcf, fn_withH)
end