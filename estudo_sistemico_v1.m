%AUTORES: LEONARDO KULAITIS PENTEADO SYPNIEWSKI; PROFa. DRa. POLYANA CAMARGO DE LACERDA; PROF. PH.D ANDRÉ AUGUSTO MARIANO

close all;
clear; clc;

%% --- Parâmetros da Carga ---
Pcarga = 1036.3e-6;          % Consumo total do LNA [W] %322e-6 somente o meu LNA; 1036e-6 considerando estudo de receptor mas com o meu LNA
Vcarga = 1.0;               % Tensão de alimentação em [V]
Icarga = Pcarga/Vcarga;     % Corrente total do LNA [A]

%% --- Parâmetros do sistema WIPT (Vref = 0.9 V) ---
C = 50e-3;                  % Capacitância do supercapacitor [F]
Resr = 160e-3;              % Resistência em série equivalente [Ohms]
Vtarget = 1.8;              % Tensão alvo de carregamento sem carga [V]

% Limiares do boost para Vref = 0.7 V (conforme datasheet pg4)
Vmax1 = 0.945;              % Tensão máxima de ativação do boost [V]
Vmin1 = 0.9;               % Tensão mínima de desligamento do boost [V]

%% --- Dados do conversor RF-DC (P21XXCSR-EVB datasheet pg11 Vref = 0.9 V banda 3) ---
Prf_dBm1 = [-14 -13 -12 -11 -10 -9 -8 -7 -6 -5 -4 -3 -2 -1 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16];
n1 = [0.015 0.08 0.20 0.32 0.39 0.455 0.485 0.515 0.516 0.50 0.48 0.475 0.50 0.53 0.55 0.57 0.575 0.574 0.57 0.55 0.535 0.51 0.48 0.45 0.42 0.39 0.36 0.34 0.30 0.275 0.25];
Prf_W1 = 10.^((Prf_dBm1 - 30) / 10);
Pdc_W1 = Prf_W1.*n1;

%% --- Aplicação do modelo de conversão RF-DC da Elena ---
M1 = 0.010;                       % Saturação da potência de saída DC 
a1 = 88;                          % Taxa de carregamento não-linear
b1 = 1e-3;                        % Tensão mínima para condução do diodo
omega1 = 1/(1+exp(a1*b1));        % Constante que assegura uma resposta de entrada zero e saída zero
phi1 = M1./(1+exp(-a1*(Prf_W1-b1))); % Função logística relacionada à potência RF recebida
Pdc_calc_W1 = (phi1-(M1*omega1))/(1-omega1); % Potência coletada pela rectenna (antena + retificador)

% Potência DC média configurada
Pdc_avg1 = 1050e-6;          % Potência DC média [W] na saída do retificador 480e-6 inicial 320e-6 1050e-6
Prf_ref1 = interp1(Pdc_calc_W1, Prf_W1, Pdc_avg1, 'linear'); % Potência RF correspondente W] na entrada do retificador

% Plotagem do gráfico da conversão Prf para Pdc (Figura 1)
figure('Name', 'Conversão RF-DC do P21XXCSR-EVB 0.9 V banda 3 = 904 MHz', 'Color', 'w');
semilogx(Prf_W1,Pdc_W1,'*','MarkerSize', 8, 'LineWidth', 2) 
grid on
hold on
semilogx(Prf_W1,Pdc_calc_W1,'-','LineWidth', 2) 
semilogx(Prf_ref1,Pdc_avg1,'*','MarkerSize', 8, 'LineWidth', 2) 
set(gca, 'FontSize', 14, 'FontWeight', 'bold') 
title('Conversão RF-DC, Banda = 904 MHz, V_r_e_f = 0.9 V', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Potência RF de Entrada [W]', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Potência DC de Saída [W]', 'FontSize', 14, 'FontWeight', 'bold');

% Constante de tempo de carga do supercapacitor baseada em Pdc_avg1
teh1 = (C * Vtarget^2) / (2 * Pdc_avg1);
taoc1 = -teh1 / log((Vtarget - 0.99*Vtarget) / Vtarget);

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
        v_curr = Vmin1;
    end
    
    t_charge_start = current_time;
    
    while v_curr < Vmax1
        t_charge(end+1) = current_time;
        v_charge(end+1) = v_curr;
        
        elapsed = 0:dt:(dt*100);
        v_trial = Vtarget - (Vtarget - v_curr) * exp(-elapsed / taoc1);
        
        if any(v_trial >= Vmax1)
            idx = find(v_trial >= Vmax1, 1);
            current_time = current_time + elapsed(idx);
            v_curr = Vmax1;
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
    v_curr = Vmax1;
    t_discharge_start = current_time;
    
    while v_curr > Vmin1
        t_discharge(end+1) = current_time;
        v_discharge(end+1) = v_curr;
        
        % Cálculo dinâmico da corrente de entrada exigida pelo boost
        Iin_desc = Icarga * (Vout / v_curr) * (1 / eta) + Ilos;
        
        % Queda de tensão 
        v_curr = v_curr - (Iin_desc * Resr) - (Iin_desc * dt / C);
        current_time = current_time + dt;
        
        if v_curr <= Vmin1
            v_curr = Vmin1;
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
fprintf('Potência RFin: %.4f W\n', Prf_ref1);
fprintf('----------------------------------------\n');
fprintf('Potência DCout: %.6f W\n', Pdc_avg1);
fprintf('----------------------------------------\n');
fprintf('Tempo de Carregamento Inicial (0V -> %.3fV): %.3f segundos\n', Vmax1, t_init_charge);
fprintf('----------------------------------------\n');
for i = 1:length(t_discharge_cycles)
    fprintf('Ciclo %d:\n', i);
    fprintf('  - Tempo de Descarga (%.3fV -> %.3fV): %.3f segundos\n', Vmax1, Vmin1, t_discharge_cycles(i));
    if i > 1
        fprintf('  - Tempo de Recarga (%.3fV -> %.3fV): %.3f segundos\n', Vmin1, Vmax1, t_recharge_cycles(i-1));
    else
        fprintf('  - Tempo de Recarga (Ciclo 1): N/A (Partiu de 0V)\n');
    end
end
fprintf('========================================\n\n');

%% --- Plotagem dos Ciclos Automáticos com Regiões de Fundo (Figura 2) ---
figure('Name', 'Ciclo Automatico de Carga e Descarga', 'Color', 'w');
hold on;

ymin = 0;
ymax = 1;

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
title(sprintf('Ciclos Automáticos - Carga: LNA@ 1 V (Boost @ V_{max} = %.3fV, V_{min} = %.3fV)', Vmax1, Vmin1), 'FontSize', 14, 'FontWeight', 'bold');
ylim([ymin ymax]);
legend('Location', 'southeast', 'FontSize', 11);
hold off;


%% --- Figura 3: Análise Paramétrica Genérica (PRFin e PDCout vs Tempo de Recarga) para 0.9 V ---
% Define um vetor de varredura para PDCout (de 200 uW a 1500 uW)
Pdc_varredura = linspace(200e-6, 1500e-6, 30); 

% Pré-alocação dos vetores de plotagem
Prf_plot = zeros(size(Pdc_varredura));
T_recarga_plot = zeros(size(Pdc_varredura));

for i = 1:length(Pdc_varredura)
    Pdc_atual = Pdc_varredura(i);
    
    % 1. Interpola PRFin para este PDCout específico (usando curvas do Vref=0.9V)
    Prf_plot(i) = interp1(Pdc_calc_W1, Prf_W1, Pdc_atual, 'linear');
    
    % 2. Calcula a nova constante taoc baseada no Pdc_atual
    teh_atual = (C * Vtarget^2) / (2 * Pdc_atual);
    taoc_atual = -teh_atual / log((Vtarget - 0.99*Vtarget) / Vtarget);
    
    % 3. Extrai o tempo de recarga analítico (Vmin1 -> Vmax1)
    T_recarga_plot(i) = -taoc_atual * log((Vtarget - Vmax1) / (Vtarget - Vmin1));
end

% Conversão para miliWatts (mW) para o gráfico ficar elegante
Prf_mW = Prf_plot * 1000;
Pdc_mW = Pdc_varredura * 1000;

% --- Plotagem do Gráfico Genérico ---
figure('Name', 'Potências vs Tempo de Recarga (0.9 V)', 'Color', 'w');

% Plot das curvas base
plot(T_recarga_plot, Prf_mW, '-*', 'Color', [0 0.4470 0.7410], 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'P_{RF_{in}} (Entrada RF)');
hold on;
plot(T_recarga_plot, Pdc_mW, '-*', 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'P_{DC_{out}} (Saída DC)');

% Estética Genérica
grid on;
ax = gca;
set(ax, 'FontSize', 14, 'FontWeight', 'bold');
title('Potências vs Tempo de Recarga (0,9 V)', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Tempo de Recarga [s]', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Potência [mW]', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 12);

% Define o limite do eixo X arredondado para o múltiplo de 0.25 mais próximo
x_max = ceil(max(T_recarga_plot) * 4) / 4; 

%  Marcas grandes (iguais) a cada 0.25s
ax.XTick = 0:0.25:x_max;

% Manter texto apenas nos múltiplos de 0.5s
labels = cell(size(ax.XTick));
for k = 1:length(ax.XTick)
    if mod(ax.XTick(k), 0.5) == 0
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