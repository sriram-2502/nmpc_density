clc;
clear;
close all;
addpath("C:\Users\Sajad\Documents\Casadi")
%% Setup and Parameters
x0 = [10; 10; 10; 2; 0; 0; 0; 0];%Initial Condition
xf = [0; 0; 0; 0; 0; 0; 0; 0]; % X final
time_total = 10;%Time for the total steps, equal to tsim
dt = 0.01;
o = 3;
Q = 10*diag([10,10,10, 10, o, o, o, o]);
P_weight = 100*diag([10,10,10,10, o, o, o, o]);
R = 1*diag([1, 1, 1, 1]);
N = 10;


%Variables range as below
xmin = [-inf; -inf; -inf;-100; -100; -100; -100; -100];
xmax = -xmin;%[10; 10; 10; 100; 100; 100; 100; 100];

umin = [-inf; -inf; -inf; -inf];
umax = -umin;

%First Obstacle
x_obs_1 = 8;
y_obs_1 = 8;
z_obs_1 = 8.5;
r_obs_1 = 1;

%Second Obstacle
x_obs_2 = 3.2;
y_obs_2 = 4.1;
z_obs_2 = 3.5;
r_obs_2 = 1.5;
%%
import casadi.*
% Symbols/expressions
x = SX.sym('x');
y = SX.sym('y');
z = SX.sym('z');
psi = SX.sym('psi');
xdot = SX.sym('xdot');
ydot = SX.sym('ydot');
zdot = SX.sym('zdot');
psidot = SX.sym('psidot');

states = [x; y; z; psi; xdot; ydot; zdot; psidot];
n_states = length(states);

%Control Inputs
u = SX.sym('u');
v = SX.sym('v');
w = SX.sym('w');
r = SX.sym('r');
controls = [u;v;w;r];
n_controls = length(controls);

% Right hand side
 %---- Parameters
            m = 54.54; %Kg
            G = 535; %N
            B = 53.4;
            Iz = 13.587;
            Xuu = 2.3e-2;
            Yvv = 5.3e-2;
            Zww = 1.7e-1;
            Nrr = 2.9e-3;
            Xudot = -7.6e-3;
            Yvdot = -5.5e-2;
            Zwdot = -2.4e-1;
            Nrdot = -3.4e-3;
            Xu = 2e-3;
            Yv = -1e-1;
            Zw = -3e-1;
            Nr = 3e-2;

           J = [cos(psi) -sin(psi) 0 0;
                sin(psi)   cos(psi) 0 0;
                0 0 1 0;
                0 0 0 1];
           X1_dot = [xdot; ydot; zdot; psidot];

           g = [0; 0; -(G-B); 0];
           Jdot = [-psidot*sin(psi) -psidot*cos(psi) 0 0;
                    psidot*cos(psi) -psidot*sin(psi) 0 0;
                    0 0 0 0;
                    0 0 0 0];
           invJ = [cos(psi) sin(psi) 0 0;
                   -sin(psi) cos(psi) 0 0;
                   0 0 1 0;
                   0 0 0 1];
           m11 = m - Xudot;
           m22 = m - Yvdot;
           m33 = m - Zwdot;
           m44 = Iz - Nrdot;
           Mt = diag([m11 m22 m33 m44]);
           M = (invJ)' * Mt * invJ;
           invM = [(7676892219811089*cos(psi)*cos(psi))/140737488355328+(10919*sin(psi)*sin(psi))/200,  (7676892219811089*cos(psi)*sin(psi))/140737488355328-(10919*sin(psi)*cos(psi))/200,       0,        0;
                        (7676892219811089*sin(psi)*cos(psi))/140737488355328-(10919*cos(psi)*sin(psi))/200,  (10919*cos(psi)*cos(psi))/200+(7676892219811089*sin(psi)*sin(psi))/140737488355328,       0,        0;
                                                                                                               0,                                                                                        0, 2739/50,        0;
                                                 0,                                                                                        0,       0, 8494/625];                                                                                           
            
           V = invJ * [xdot; ydot; zdot; psidot];
            d11 = -Xu - Xuu * abs(V(1));
            d22 = -Yv - Yvv * abs(V(2));
            d33 = -Zw - Zww * abs(V(3));
            d44 = -Nr - Nrr * abs(V(4));                                                                                
            Dv = diag([d11, d22, d33, d44]);
            D = (invJ)' * Dv * invJ;
            
            
            Cv = [0 0 0 -(m-Yvdot)*V(2);
                      0 0 0 (m-Xudot)*V(1);
                      0 0 0 0;
                      (m-Yvdot)*V(2) -(m-Xudot)*V(1) 0 0];
            C = (invJ)' * (Cv - M * invJ * Jdot) * invJ;
            fx = invM * (-C * [xdot; ydot; zdot; psidot] - D * [xdot; ydot; zdot; psidot]);
            F_sys = [xdot; ydot; zdot; psidot;fx];
            
            jacob_F = jacobian(dt*F_sys + states , [x; y; z; psi; xdot; ydot; zdot; psidot]');
            % jacob_F = jacobian(F_sys , [x; y; z; psi; xdot; ydot; zdot; psidot]');
            dive_F = sum(diag(jacob_F));
            
          
            G_sys = dt*[zeros(4);invM * (invJ)'];
             % G_sys = dt*[zeros(4);invM * (invJ)'];
            G_sys_1 = G_sys(:,1);
            jacob_G_sys_1 = jacobian(G_sys_1,[x; y; z; psi; xdot; ydot; zdot; psidot]');
            dive_G_sys_1 = sum(diag(jacob_G_sys_1));
            G_sys_2 = G_sys(:,2);
            jacob_G_sys_2 = jacobian(G_sys_2,[x; y; z; psi; xdot; ydot; zdot; psidot]');
            dive_G_sys_2 = sum(diag(jacob_G_sys_2));
            G_sys_3 = G_sys(:,3);
            jacob_G_sys_3 = jacobian(G_sys_3,[x; y; z; psi; xdot; ydot; zdot; psidot]');
            dive_G_sys_3 = sum(diag(jacob_G_sys_3));
            G_sys_4 = G_sys(:,4);
            jacob_G_sys_4 = jacobian(G_sys_4,[x; y; z; psi; xdot; ydot; zdot; psidot]');
            dive_G_sys_4 = sum(diag(jacob_G_sys_4));
            
            u_sys = invM * (invJ)' * controls;
            X2_dot = fx + u_sys;
        
rhs = [X1_dot; X2_dot];

% hk = (x-x_obs_1)^2 + (y-y_obs_1)^2 + (z-z_obs_1)^2 - r_obs_1^2;
% Sk = (x-x_obs_1)^2 + (y-y_obs_1)^2 + (z-z_obs_1)^2 - (r_obs_1+1)^2 ;
% temp1 = hk / (hk-Sk);
% f_bar1 = if_else(temp1 > 0, exp(-1/temp1), 0)/(if_else(temp1 > 0, exp(-1/temp1), 0) + if_else(1-temp1 > 0, exp(-1/(1-temp1)), 0));
% Phi = f_bar1;
% V = ([st(1) st(2) st(3) st(4)] *P_lyap*[st(1); st(2); st(3); st(4)]);
% rho = Phi/(V.^alpha);

% nonlinear mapping function f(x,u)
f = Function('f',{states,controls},{rhs}); 
Dive_F = Function('Dive_F',{states},{dive_F});
Dive_G_1 = Function('Dive_G_1',{states},{dive_G_sys_1});
Dive_G_2 = Function('Dive_G_2',{states},{dive_G_sys_2});
Dive_G_3 = Function('Dive_G_3',{states},{dive_G_sys_3});
Dive_G_4 = Function('Dive_G_4',{states},{dive_G_sys_4});



f1 = Function('f1',{states},{F_sys}); 
g1 = Function('g',{states},{G_sys});
% Decision variables (controls)
U = SX.sym('U',n_controls,N); 
C = SX.sym('C',N); 
% parameters (which include at the initial state of the robot and the reference state)
P = SX.sym('P',n_states + n_states);
% A vector that represents the states over the optimization problem.
X = SX.sym('X',n_states,(N+1));

obj = 0; % Objective function
g = [];  % constraints vector

st  = X(:,1); % initial state
g = [g;st-P(1:8)]; % initial condition constraints
for k = 1:N
    st = X(:,k);
    con = U(:,k);
    obj = obj+(st-P(9:16))'*Q*(st-P(9:16)) + con'*R*con; % calculate obj
    st_next = X(:,k+1);
    f_value = f(st,con);
    st_next_euler = st+ (dt*f_value);
    g = [g;st_next-st_next_euler]; % compute constraints
end



%Add Terminal Cost
k = N+1;
st = X(:,k);
obj = obj+(st-P(9:16))'*P_weight*(st-P(9:16)); % calculate obj

%Adding density function
% tau = SX.sym('tau');
% y = if_else(tau > 0, exp(-1/tau), 0);
% f = Function('f', {tau}, {y});
% f_bar = f(tau)/(f(tau)+f(1-tau));
% Sk = (r_obs+2)^2;
P_lyap = eye(8);
alpha = 1.1;
for k = 1:N
    st = X(:,k);
    con = U(:,k);
    hk = (st(1)-x_obs_1)^2 + (st(2)-y_obs_1)^2 + (st(3)-z_obs_1)^2 - r_obs_1^2;
    Sk = (st(1)-x_obs_1)^2 + (st(2)-y_obs_1)^2 + (st(3)-z_obs_1)^2 - (r_obs_1+1)^2 ;
    temp1 = hk / (hk-Sk);
    f_bar1 = if_else(temp1 > 0, exp(-1/temp1), 0)/(if_else(temp1 > 0, exp(-1/temp1), 0) + if_else(1-temp1 > 0, exp(-1/(1-temp1)), 0));
    Phi = f_bar1;
    V = [st(1) st(2) st(3) st(4) st(5) st(6) st(7) st(8)] *P_lyap*([st(1); st(2); st(3); st(4); st(5); st(6); st(7); st(8)]);
    rho = Phi/(V.^alpha);

    st_next = X(:,k+1);
    % con_next = U(:,k+1);
    hk_next = (st_next(1)-x_obs_1)^2 + (st_next(2)-y_obs_1)^2 + (st_next(3)-z_obs_1)^2 - r_obs_1^2;
    Sk_next = (st_next(1)-x_obs_1)^2 + (st_next(2)-y_obs_1)^2 + (st_next(3)-z_obs_1)^2 - (r_obs_1+1)^2 ;
    temp2 = hk_next/(hk_next-Sk_next);
    f_bar2 = if_else(temp2 > 0, exp(-1/temp2), 0)/(if_else(temp2 > 0, exp(-1/temp2), 0) + if_else(1-temp2 > 0, exp(-1/(1-temp2)), 0));
    Phi_next = f_bar2;
    V_next = [st_next(1) st_next(2) st_next(3) st_next(4) st_next(5) st_next(6) st_next(7) st_next(8)] *P_lyap*([st_next(1); st_next(2); st_next(3); st_next(4); st_next(5); st_next(6); st_next(7); st_next(8)]);
    rho_next = Phi_next/(V_next.^alpha);


    f_value = f1(st);
    f_value_next = f1(st_next);
    C1 = Dive_F(st);
    C1 = C1*rho;

    % C2_1 = Dive_G_1(st);


    g = [g; rho_next - rho + dt*C1];

end


P_lyap = eye(8);
for k = 1:N
    st = X(:,k);
    hk = (st(1)-x_obs_2)^2 + (st(2)-y_obs_2)^2 + (st(3)-z_obs_2)^2 - r_obs_2^2;
    Sk = (st(1)-x_obs_2)^2 + (st(2)-y_obs_2)^2 + (st(3)-z_obs_2)^2 - (r_obs_2+1)^2 ;
    temp1 = hk / (hk-Sk);
    f_bar1 = if_else(temp1 > 0, exp(-1/temp1), 0)/(if_else(temp1 > 0, exp(-1/temp1), 0) + if_else(1-temp1 > 0, exp(-1/(1-temp1)), 0));
    Phi = f_bar1;
    V = [st(1) st(2) st(3) st(4) st(5) st(6) st(7) st(8)] *P_lyap*([st(1); st(2); st(3); st(4); st(5); st(6); st(7); st(8)]);
    rho = Phi/(V.^alpha);

    st_next = X(:,k+1);
    hk_next = (st_next(1)-x_obs_2)^2 + (st_next(2)-y_obs_2)^2 + (st_next(3)-z_obs_2)^2 - r_obs_2^2;
    Sk_next = (st_next(1)-x_obs_2)^2 + (st_next(2)-y_obs_2)^2 + (st_next(3)-z_obs_2)^2 - (r_obs_2+1)^2 ;
    temp2 = hk_next/(hk_next-Sk_next);
    f_bar2 = if_else(temp2 > 0, exp(-1/temp2), 0)/(if_else(temp2 > 0, exp(-1/temp2), 0) + if_else(1-temp2 > 0, exp(-1/(1-temp2)), 0));
    Phi_next = f_bar2;
    V_next = [st_next(1) st_next(2) st_next(3) st_next(4) st_next(5) st_next(6) st_next(7) st_next(8)] *P_lyap*([st_next(1); st_next(2); st_next(3); st_next(4); st_next(5); st_next(6); st_next(7); st_next(8)]);
    rho_next = Phi_next/(V_next.^alpha);

    
    C1 = Dive_F(st);
    C1 = C1*rho;

    % C2_1 = Dive_G_1(st);


    g = [g; rho_next - rho + dt*C1];
    
end





% make the decision variable one column  vector
OPT_variables = [reshape(X,8*(N+1),1);reshape(U,4*N,1)];
nlp_prob = struct('f', obj, 'x', OPT_variables, 'g', g, 'p', P);

opts = struct;
opts.ipopt.max_iter = 100;
opts.ipopt.print_level =0;%0,3
opts.print_time = 0;
opts.ipopt.acceptable_tol =1e-8;
opts.ipopt.acceptable_obj_change_tol = 1e-6;

solver = nlpsol('solver', 'ipopt', nlp_prob,opts);

args = struct;
args.lbg(1:8*(N+1)) = 0; % equality constraints
args.ubg(1:8*(N+1)) = 0; % equality constraints

args.lbg(8*(N+1)+1 : 8*(N+1)+ (2*N)) = 0; % inequality constraints
args.ubg(8*(N+1)+1 : 8*(N+1)+ (2*N)) = inf; % inequality constraints

args.lbx(1:8:8*(N+1),1) = xmin(1); %state x lower bound
args.ubx(1:8:8*(N+1),1) = xmax(1); %state x upper bound
args.lbx(2:8:8*(N+1),1) = xmin(2); %state y lower bound
args.ubx(2:8:8*(N+1),1) = xmax(2); %state y upper bound
args.lbx(3:8:8*(N+1),1) = xmin(3); %state z lower bound
args.ubx(3:8:8*(N+1),1) = xmax(3); %state z upper bound
args.lbx(4:8:8*(N+1),1) = xmin(4); %state psi lower bound
args.ubx(4:8:8*(N+1),1) = xmax(4); %state psi upper bound
args.lbx(5:8:8*(N+1),1) = xmin(5); %state xdot lower bound
args.ubx(5:8:8*(N+1),1) = xmax(5); %state xdot upper bound
args.lbx(6:8:8*(N+1),1) = xmin(6); %state ydot lower bound
args.ubx(6:8:8*(N+1),1) = xmax(6); %state ydot upper bound
args.lbx(7:8:8*(N+1),1) = xmin(7); %state zdot lower bound
args.ubx(7:8:8*(N+1),1) = xmax(7); %state zdot upper bound
args.lbx(8:8:8*(N+1),1) = xmin(8); %state psidot lower bound
args.ubx(8:8:8*(N+1),1) = xmax(8); %state psidot upper bound

args.lbx(8*(N+1)+1:4:8*(N+1)+4*N,1) = umin(1); %u lower bound
args.ubx(8*(N+1)+1:4:8*(N+1)+4*N,1) = umax(1); %u upper bound
args.lbx(8*(N+1)+2:4:8*(N+1)+4*N,1) = umin(2); %p lower bound
args.ubx(8*(N+1)+2:4:8*(N+1)+4*N,1) = umax(2); %p upper bound
args.lbx(8*(N+1)+3:4:8*(N+1)+4*N,1) = umin(3); %q lower bound
args.ubx(8*(N+1)+3:4:8*(N+1)+4*N,1) = umax(3); %q upper bound
args.lbx(8*(N+1)+4:4:8*(N+1)+4*N,1) = umin(4); %r lower bound
args.ubx(8*(N+1)+4:4:8*(N+1)+4*N,1) = umax(4); %r upper bound




%% Simulation
t0 = 0;


xlog(:,1) = x0; % xx contains the history of states
t(1) = t0;

u0 = zeros(N,4);
X0 = repmat(x0,1,N+1)';

% Start MPC
mpciter = 0;
xx1 = [];
u_cl=[];

tic
while(norm((x0-xf),2) > 1e-2 && mpciter < time_total / dt)
    args.p   = [x0;xf]; % set the values of the parameters vector
    % initial value of the optimization variables
    args.x0  = [reshape(X0',8*(N+1),1);reshape(u0',4*N,1)];
    sol = solver('x0', args.x0, 'lbx', args.lbx, 'ubx', args.ubx,...
        'lbg', args.lbg, 'ubg', args.ubg,'p',args.p);
    u = reshape(full(sol.x(8*(N+1)+1:end))',4,N)'; % get controls only from the solution
    xx1(:,1:8,mpciter+1)= reshape(full(sol.x(1:8*(N+1)))',8,N+1)'; % get solution TRAJECTORY
    u_cl= [u_cl ; u(1,:)];
    t(mpciter+1) = t0;
    % Apply the control and shift the solution
    [t0, x0, u0] = shift(dt, t0, x0, u,f);
    xlog(:,mpciter+1) = x0;
    X0 = reshape(full(sol.x(1:8*(N+1)))',8,N+1)'; % get solution TRAJECTORY
    % Shift trajectory to initialize the next step
    X0 = [X0(2:end,:);X0(end,:)];
    mpciter
    mpciter = mpciter + 1;
end
toc


Line_width = 2;
Line_color = 'black';

figure
hold on
subplot(2,2,1);
plot(linspace(0, time_total, length(xlog) ), xlog(1,:),...
    'LineWidth',Line_width ,'MarkerSize',4,'Color',Line_color);
% xlabel('$t(s)$','interpreter','latex','FontSize',20);
ylabel('$x(m) $','interpreter','latex','FontSize',10);

subplot(2,2,2);
hold on
plot(linspace(0, time_total, length(xlog(1,:)) ), xlog(2,:),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
% xlabel('$t(s)$','interpreter','latex','FontSize',20);
ylabel('$y(m) $','interpreter','latex','FontSize',10);

subplot(2,2,3);
hold on
plot(linspace(0, time_total, length(xlog(1,:)) ), xlog(3,:),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
xlabel('$Time(sec.)$','interpreter','latex','FontSize',10);
ylabel('$z(m) $','interpreter','latex','FontSize',10);

subplot(2,2,4);
hold on
plot(linspace(0, time_total, length(xlog(1,:)) ), xlog(4,:),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
xlabel('$Time(sec.)$','interpreter','latex','FontSize',10);
ylabel('$\psi(deg)$','interpreter','latex','FontSize',10);

figure
hold on
subplot(2,2,1);
hold on
plot(linspace(0, time_total, length(xlog(1,:)) ), xlog(5,:),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
% xlabel('$t(s)$','interpreter','latex','FontSize',20);
ylabel('$u(m/s)$','interpreter','latex','FontSize',10);

subplot(2,2,2);
hold on
plot(linspace(0, time_total, length(xlog(1,:)) ), xlog(6,:),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
% xlabel('$t(s)$','interpreter','latex','FontSize',20);
ylabel('$v(m/s)$','interpreter','latex','FontSize',10);

subplot(2,2,3);
hold on
plot(linspace(0, time_total, length(xlog(1,:)) ), xlog(7,:),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
xlabel('$Time(sec.)$','interpreter','latex','FontSize',10);
ylabel('$w(m/s)$','interpreter','latex','FontSize',10);

subplot(2,2,4);
hold on
plot(linspace(0, time_total, length(xlog(1,:)) ), xlog(8,:),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
xlabel('$Time(sec.)$','interpreter','latex','FontSize',10);
ylabel('$r(rad/s)$','interpreter','latex','FontSize',10);
% 
% 
%    sgtitle('States')


figure
hold on
subplot(2,2,1);
plot(linspace(0, time_total, length(u_cl(:,1))),u_cl(:,1),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
xlabel('$t (s)$','interpreter','latex','FontSize',20);
ylabel('$f_{surge}(N)$','interpreter','latex','FontSize',10);

subplot(2,2,2);
hold on
plot(linspace(0, time_total, length(u_cl(:,1))),u_cl(:,2),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
% xlabel('$t (s)$','interpreter','latex','FontSize',20);
ylabel('$f_{sway}(N)$','interpreter','latex','FontSize',10);

subplot(2,2,3);
hold on
plot(linspace(0, time_total, length(u_cl(:,1))),u_cl(:,3),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
xlabel('$Time(sec.)$','interpreter','latex','FontSize',10);
ylabel('$f_{heave}(N)$','interpreter','latex','FontSize',10);

subplot(2,2,4);
hold on
plot(linspace(0, time_total, length(u_cl(:,1))),u_cl(:,4),...
    'LineWidth', Line_width,'MarkerSize',4,'Color',Line_color);
xlabel('$Time(sec.)$','interpreter','latex','FontSize',10);
ylabel('$\tau_{yaw}(N.m)$','interpreter','latex','FontSize',10);
% sgtitle('Control Inputs')


figure
% hold on
plot3(xlog(1,:), xlog(2,:), xlog(3,:),'LineWidth', Line_width,'Color','red')
xlabel('x(m)','interpreter','latex','FontSize',20);
ylabel('y(m)','interpreter','latex','FontSize',20);
zlabel('z(m)','interpreter','latex','FontSize',20);
hold on
[X,Y,Z] = sphere;
% 
surf(r_obs_1*(X)+x_obs_1,r_obs_1*(Y)+y_obs_1,r_obs_1*(Z)+z_obs_1)
surf(r_obs_2*(X)+x_obs_2,r_obs_2*(Y)+y_obs_2,r_obs_2*(Z)+z_obs_2)

%%
F_values = [];
for i=1:length(xlog)
    F_values = [F_values;Dive_F(xlog(:,i))];
end



