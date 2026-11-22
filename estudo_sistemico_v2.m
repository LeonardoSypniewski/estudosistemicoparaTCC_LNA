%AUTORES: LEONARDO KULAITIS PENTEADO SYPNIEWSKI; PROFa. DRa. POLYANA CAMARGO DE LACERDA; PROF. PH.D ANDRÉ AUGUSTO MARIANO

close all;
clear; clc;

%% --- Parâmetros da Carga ---
Pcarga = 322.3e-6;          % Consumo total do LNA [W] %322,3e-6 somente o meu LNA; 1036e-6 considerando estudo de receptor mas com o meu LNA
Vcarga = 1.0;               % Tensão de alimentação em [V]
Icarga = Pcarga/Vcarga;     % Corrente total do LNA [A]

%% --- Parâmetros do sistema WIPT (Vref = 0.7 V) ---
C = 50e-3;                  % Capacitância do supercapacitor [F]
Resr = 160e-3;              % Resistência em série equivalente [Ohms]
Vtarget = 1.8;              % Tensão alvo de carregamento sem carga [V]

% Limiares do boost para Vref = 0.7 V (conforme datasheet pg4)
Vmax2 = 0.738;              % Tensão máxima de ativação do boost [V]
Vmin2 = 0.64;               % Tensão mínima de desligamento do boost [V]

%% --- Dados do conversor RF-DC (P21XXCSR-EVB datasheet pg11 Vref = 0.7 V banda 3) ---
Prf_dBm2 = [-15 -14 -13 -12 -11 -10 -9 -8 -7 -6 -5 -4 -3 -2 -1 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16];
n2 = [0.025 0.11 0.21 0.32 0.38 0.44 0.46 0.475 0.47 0.465 0.45 0.445 0.47 0.50 0.52 0.53 0.535 0.53 0.525 0.515 0.49 0.47 0.445 0.42 0.385 0.36 0.33 0.315 0.28 0.26 0.23 0.22];
Prf_W2 = 10.^((Prf_dBm2 - 30) / 10);
Pdc_W2 = Prf_W2.*n2;

%% --- Aplicação do modelo de conversão RF-DC da Elena ---
M2 = 0.009;                                % Saturação da potência de saída DC 
a2 = 85;                                   % Taxa de carregamento não-linear
b2 = 1e-3;                                 % Tensão mínima para condução do diodo
omega2 = 1/(1+exp(a2*b2));                 % Constante que assegura uma resposta de entrada zero e saída zero
phi2 = M2./(1+exp(-a2*(Prf_W2-b2)));       % Função logística relacionada à potência RF recebida
Pdc_calc_W2 = (phi2-(M2*omega2))/(1-omega2); % Potência coletada pela rectenna (antena + retificador)

% Potência DC média configurada
Pdc_avg2 = 1100e-6;                         % Potência DC média [W] na saída do retificador %390e-6 e 1100e-6 
Prf_ref2 = interp1(Pdc_calc_W2, Prf_W2, Pdc_avg2, 'linear'); % Potência RF correspondente W] na entrada do retificador

% Plotagem do gráfico da conversão Prf para Pdc (Figura 1)
figure('Name', 'Conversão RF-DC do P21XXCSR-EVB 0.7 V banda 3 = 904 MHz', 'Color', 'w');
semilogx(Prf_W2,Pdc_W2,'*','MarkerSize', 8, 'LineWidth', 2) 
grid on
hold on
semilogx(Prf_W2,Pdc_calc_W2,'-','LineWidth', 2) 
semilogx(Prf_ref2,Pdc_avg2,'*','MarkerSize', 8, 'LineWidth', 2) 
set(gca, 'FontSize', 14, 'FontWeight', 'bold') 
title('Conversão RF-DC, Banda = 904 MHz, V_r_e_f = 0.7 V', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Potência RF de Entrada [W]', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Potência DC de Saída [W]', 'FontSize', 14, 'FontWeight', 'bold');

% Constante de tempo de carga do supercapacitor baseada em Pdc_avg2
teh2 = (C * Vtarget^2) / (2 * Pdc_avg2);
taoc2 = -teh2 / log((Vtarget - 0.99*Vtarget) / Vtarget);

%% --- Parâmetros do Conversor Boost e Carga ---
Vout = Vcarga;              % Tensão de alimentação da carga
eta = 0.80;                 % Eficiência do boost
Ilos = 0;                   % Perdas durante a operação do boost 

%% --- Simulação do Ciclo Automático de Carga e Descarga ---
num_cycles = 5;             % Número de ciclos desejados
t_total = [];
v_total = [];
current_time = 0;
dt = 0.01;                  % Passo de tempo [s]

% Vetores para armazenar intervalos de tempo das regiões
intervals_init = [];
intervals_recharge = [];
intervals_discharge = [];

% Vetores para métricas de tempo
t_init_charge = 0;
t_recharge_cycles = [];
t_discharge_cycles = [];

for c = 1:num_cycles
    %% 1. Fase de Carga (EH Phase)
    v_charge = [];
    t_charge = [];
    
    if c == 1
        v_curr = 0.0;
    else
        v_curr = Vmin2;
    end
    
    t_charge_start = current_time;
    
    while v_curr < Vmax2
        t_charge(end+1) = current_time;
        v_charge(end+1) = v_curr;
        
        elapsed = 0:dt:(dt*100);
        v_trial = Vtarget - (Vtarget - v_curr) * exp(-elapsed / taoc2);
        
        if any(v_trial >= Vmax2)
            idx = find(v_trial >= Vmax2, 1);
            current_time = current_time + elapsed(idx);
            v_curr = Vmax2;
            t_charge(end+1) = current_time;
            v_charge(end+1) = v_curr;
            break;
        else
            current_time = current_time + dt;
            v_curr = v_trial(2);
        end
    end
    
    charge_duration = current_time - t_charge_start;
    
    if c == 1
        t_init_charge = charge_duration;
        intervals_init = [t_charge_start, current_time];
    else
        t_recharge_cycles(end+1) = charge_duration;
        intervals_recharge = [intervals_recharge; t_charge_start, current_time];
    end
    
    t_total = [t_total t_charge(1:end-1)];
    v_total = [v_total v_charge(1:end-1)];
    
    %% 2. Fase de Descarga (Boost Ativado / Carga Alimentada)
    v_discharge = [];
    t_discharge = [];
    v_curr = Vmax2;
    t_discharge_start = current_time;
    
    while v_curr > Vmin2
        t_discharge(end+1) = current_time;
        v_discharge(end+1) = v_curr;
        
        % Cálculo dinâmico da corrente de entrada exigida pelo boost
        Iin_desc = Icarga * (Vout / v_curr) * (1 / eta) + Ilos;
        
        % Queda de tensão 
        v_curr = v_curr - (Iin_desc * Resr) - (Iin_desc * dt / C);
        current_time = current_time + dt;
        
        if v_curr <= Vmin2
            v_curr = Vmin2;
            t_discharge(end+1) = current_time;
            v_discharge(end+1) = v_curr;
            break;
        end
    end
    
    discharge_duration = current_time - t_discharge_start;
    t_discharge_cycles(end+1) = discharge_duration;
    intervals_discharge = [intervals_discharge; t_discharge_start, current_time];
    
    t_total = [t_total t_discharge];
    v_total = [v_total v_discharge];
end

%% --- Exibição dos Tempos no Command Window ---
fprintf('\n========================================\n');
fprintf('        RELATÓRIO DE TEMPOS (LNA)       \n');
fprintf('========================================\n');
fprintf('Potência RFin: %.4f W\n', Prf_ref2);
fprintf('----------------------------------------\n');
fprintf('Potência DCout: %.6f W\n', Pdc_avg2);
fprintf('----------------------------------------\n');
fprintf('Tempo de Carregamento Inicial (0V -> %.3fV): %.3f segundos\n', Vmax2, t_init_charge);
fprintf('----------------------------------------\n');
for i = 1:length(t_discharge_cycles)
    fprintf('Ciclo %d:\n', i);
    fprintf('  - Tempo de Descarga (%.3fV -> %.3fV): %.3f segundos\n', Vmax2, Vmin2, t_discharge_cycles(i));
    if i > 1
        fprintf('  - Tempo de Recarga (%.3fV -> %.3fV): %.3f segundos\n', Vmin2, Vmax2, t_recharge_cycles(i-1));
    else
        fprintf('  - Tempo de Recarga (Ciclo 1): N/A (Partiu de 0V)\n');
    end
end
fprintf('========================================\n\n');

%% --- Plotagem dos Ciclos Automáticos com Regiões de Fundo (Figura 2) ---
figure('Name', 'Ciclo Automatico de Carga e Descarga', 'Color', 'w');
hold on;

ymin = 0;
ymax = 0.85;

% 1. Sombreamento do Carregamento Inicial (Vermelho Claro)
if ~isempty(intervals_init)
    patch([intervals_init(1) intervals_init(2) intervals_init(2) intervals_init(1)], ...
          [ymin ymin ymax ymax], [1 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.4, ...
          'DisplayName', 'Fase de carregamento inicial (Fase EH inicial)');
end

% 2. Sombreamento das Recargas (Verde Claro)
for i = 1:size(intervals_recharge, 1)
    p = patch([intervals_recharge(i,1) intervals_recharge(i,2) intervals_recharge(i,2) intervals_recharge(i,1)], ...
              [ymin ymin ymax ymax], [0.85 1 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.4);
    if i == 1
        p.DisplayName = 'Recarga (Fase EH)';
    else
        set(get(get(p,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    end
end

% 3. Sombreamento das Descargas (Amarelo/Laranja Claro)
for i = 1:size(intervals_discharge, 1)
    p = patch([intervals_discharge(i,1) intervals_discharge(i,2) intervals_discharge(i,2) intervals_discharge(i,1)], ...
              [ymin ymin ymax ymax], [1 0.95 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.4);
    if i == 1
        p.DisplayName = 'Descarga (Fase de consumo)';
    else
        set(get(get(p,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
    end
end

% 4. Curva principal contínua em azul cobrindo o gráfico
plot(t_total, v_total, 'b-', 'LineWidth', 2, 'DisplayName', 'Tensão do Supercapacitor');

grid on;
xlabel('Tempo [s]', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Tensão no Supercapacitor [V]', 'FontSize', 14, 'FontWeight', 'bold');
title(sprintf('Ciclos Automáticos - Carga: LNA@ 1 V (Boost @ V_{max} = %.3fV, V_{min} = %.3fV)', Vmax2, Vmin2), 'FontSize', 14, 'FontWeight', 'bold');
ylim([ymin ymax]);
legend('Location', 'southeast', 'FontSize', 11);
hold off;

%% --- Figura 3: Análise Paramétrica Genérica (PRFin e PDCout vs Tempo de Recarga) para 0.7 V ---
% Define um vetor de varredura para PDCout (de 300 uW a 1500 uW)
Pdc_varredura = linspace(300e-6, 1500e-6, 30); 

% Pré-alocação dos vetores de plotagem
Prf_plot = zeros(size(Pdc_varredura));
T_recarga_plot = zeros(size(Pdc_varredura));

for i = 1:length(Pdc_varredura)
    Pdc_atual = Pdc_varredura(i);
    
    % 1. Interpola PRFin para este PDCout específico (usando curvas do Vref=0.7V)
    Prf_plot(i) = interp1(Pdc_calc_W2, Prf_W2, Pdc_atual, 'linear');
    
    % 2. Calcula a nova constante taoc baseada no Pdc_atual
    teh_atual = (C * Vtarget^2) / (2 * Pdc_atual);
    taoc_atual = -teh_atual / log((Vtarget - 0.99*Vtarget) / Vtarget);
    
    % 3. Extrai o tempo de recarga analítico (Vmin2 -> Vmax2)
    T_recarga_plot(i) = -taoc_atual * log((Vtarget - Vmax2) / (Vtarget - Vmin2));
end

% Conversão para miliWatts (mW) para o gráfico ficar elegante
Prf_mW = Prf_plot * 1000;
Pdc_mW = Pdc_varredura * 1000;

% --- Plotagem do Gráfico Genérico ---
figure('Name', 'Potências vs Tempo de Recarga (0.7 V)', 'Color', 'w');

% Plot das curvas base
plot(T_recarga_plot, Prf_mW, '-*', 'Color', [0 0.4470 0.7410], 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'P_{RF_{in}} (Entrada RF)');
hold on;
plot(T_recarga_plot, Pdc_mW, '-*', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'P_{DC_{out}} (Saída DC)');

% Estética Genérica
grid on;
ax = gca;
set(ax, 'FontSize', 14, 'FontWeight', 'bold');
title('Potências vs Tempo de Recarga (0,7 V)', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Tempo de Recarga [s]', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Potência [mW]', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 12);

% Define o limite do eixo X arredondado para o múltiplo de 0.25 mais próximo
x_max = ceil(max(T_recarga_plot) * 4) / 4; 

% 1. Marcas grandes (iguais) a cada 0.25s
ax.XTick = 0:0.25:x_max;

% 2. Manter texto apenas nos múltiplos de 0.5s
labels = cell(size(ax.XTick));
for k = 1:length(ax.XTick)
    % Multiplicar por 100 e usar round evita erros de ponto flutuante do MATLAB
    if mod(round(ax.XTick(k) * 100), 50) == 0
        labels{k} = num2str(ax.XTick(k)); % Mantém o número
    else
        labels{k} = ''; % Remove o texto das marcas de 0.25, 0.75, etc.
    end
end
ax.XTickLabel = labels;

% 3. Tracinhos menores (minor ticks) a cada 0.05s
ax.XMinorTick = 'on';
ax.XAxis.MinorTickValues = 0:0.05:x_max;


hold off;