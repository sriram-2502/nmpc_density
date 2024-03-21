clc;
clear;
% close all;
import casadi.*
addpath dynamics\ density_functions\ barrier_functions\

% setup colors for plots
colors = colororder;
blue = colors(1,:);
red = colors(2,:);
yellow = colors(3,:);
green = colors(5,:);
obsColor = [.7 .7 .7]; % Obstacle color -> Grey

%% Setup Parameters
% ---------- system setup ---------------
% states for AUV
x = SX.sym('x');
y = SX.sym('y');
theta = SX.sym('theta');
v = SX.sym('v');
states = [x; y; theta; v];
n_states = length(states);

% control Inputs for AUV
w = SX.sym('w');
a = SX.sym('a');
controls = [w;a];
n_controls = length(controls);

%---------- MPC setup ----------------------
time_total = 10; % time for the total steps, equal to tsim
N = 100; % for mismatch use N = 100
dt = 0.1; % use dt = 0.1 for cbf and vanilla obs
o = 3;
Q = 100*diag([10,10,o,o]);
P_weight = 1e3*diag([10,10,o,o]);
R = 10*diag([1, 1]);


xmin = [-inf; -inf; -inf; -inf];
xmax = -xmin;

umin = [-1; -10];
umax = -umin;

% ----------- Environment setup --------------------
% initial Conditions on a grid
x0 = [0;0.01;0;0]; x_ini = x0;
xf = [10;0;0;0]; % target

obs_x = SX.sym('obs_x');
obs_y = SX.sym('obs_y');
obs_r = SX.sym('obs_r');
obs_s = SX.sym('obs_s');
obs = [obs_x;obs_y;obs_r;obs_s];

% obstacle list for sphere world
num_obs = 1; % Number of obstacles
obs_rad = 1;
obs_sens = obs_rad + 1;
obs1 = [4; 0; obs_rad(1); obs_sens(1)];

%---------- cbf/obstalce constraint setup ---------------
b_circle = CBF_circle(states,obs);
b_circle = Function('b',{states,obs},{b_circle}); 

% for vanilla obs constraint: x not in x_obs
obstacle_constraint = false;

% for cbf: h_k+1 >= (1-gamma)*h_k
cbf_constraint = ~obstacle_constraint; 
gamma = 0.2;


%% Dynamics Setup 
% dynamics without paramter mismatch
mismatch = false;
[dx_dt] = unicycle_dynamics_extended(states, controls, mismatch);
% define matlab functions for F=f+gu, f, g
F = Function('F',{states,controls},{dx_dt});

% dynamics with paramter mismatch
mismatch = false;
[dx_dt_mismatch] = unicycle_dynamics_extended(states, controls, mismatch);
F_mismatch = Function('F',{states,controls},{dx_dt_mismatch}); 

%% Casdai MPC setup
% A vector that represents the states over the optimization problem.
X = SX.sym('X',n_states,(N+1));

% Decision variables for control
U = SX.sym('U',n_controls,N); 


% parameters (which include at the initial state of the robot and the reference state)
P = SX.sym('P',n_states + n_states);

obj = 0; % Objective function
constraints = [];  % constraints vector

st  = X(:,1); % initial state
constraints = [constraints;st-P(1:n_states)]; % initial condition constraints

%------------- Compute cost and constriants -------------------------
% compute running cost and dynamics constraint
for k = 1:N
    st = X(:,k);
    con = U(:,k);
    obj = obj+(st-P(n_states+1:2*n_states))'*Q*(st-P(n_states+1:2*n_states)) + con'*R*con; % calculate obj
    st_next = X(:,k+1);
    f_value = F(st,con);
    st_next_euler = st+ (dt*f_value);
    constraints = [constraints;st_next-st_next_euler]; % compute constraints
end

% Add Terminal Cost
k = N+1;
st = X(:,k);
obj = obj+(st-P(n_states+1:2*n_states))'*P_weight*(st-P(n_states+1:2*n_states)); % calculate obj

% constraint for obstacles (cbf of vanilla)
for obs_num = 1:num_obs
    for k = 1:N
        % get current and next state
        st = X(:,k); st_next = X(:,k+1);
        % get current control
        con = U(:,k);

        % get obs location
        obs_loc = eval(sprintf('obs%d',obs_num));

        % get current and next b(barrier)
        b = b_circle(st,obs_loc);
        b_next =b_circle(st_next,obs_loc);

        if(cbf_constraint)
            % form CBF constraint
            % h_k+1 >= (1-gamma)*h_k
            CBF_constraint = b_next - b  + gamma*b;
            constraints = [constraints; CBF_constraint];
        else
            % form vanilla constraint
            % h(x) >= 0
            obs_constraint = b;
            constraints = [constraints; obs_constraint];
        end
    end
end


%------------- Setup optimization problem -------------------------
% make the decision variable one column  vector
OPT_variables = [reshape(X,n_states*(N+1),1);reshape(U,n_controls*N,1)];
nlp_prob = struct('f', obj, 'x', OPT_variables, 'g', constraints, 'p', P);

opts = struct;
opts.ipopt.max_iter = 100;
opts.ipopt.print_level =0;
opts.print_time = 0;
opts.ipopt.acceptable_tol =1e-8;
opts.ipopt.acceptable_obj_change_tol = 1e-6;

solver = nlpsol('solver', 'ipopt', nlp_prob,opts);

args = struct;
args.lbg(1:n_states*(N+1)) = 0; % equality constraints
args.ubg(1:n_states*(N+1)) = 0; % equality constraints

args.lbg(n_states*(N+1)+1 : n_states*(N+1)+ (num_obs*N)) = 0; % inequality constraints
args.ubg(n_states*(N+1)+1 : n_states*(N+1)+ (num_obs*N)) = inf; % inequality constraints

args.lbx(1:n_states:n_states*(N+1),1) = xmin(1); %state x lower bound
args.ubx(1:n_states:n_states*(N+1),1) = xmax(1); %state x upper bound
args.lbx(2:n_states:n_states*(N+1),1) = xmin(2); %state y lower bound
args.ubx(2:n_states:n_states*(N+1),1) = xmax(2); %state y upper bound
args.lbx(3:n_states:n_states*(N+1),1) = xmin(3); %state theta lower bound
args.ubx(3:n_states:n_states*(N+1),1) = xmax(3); %state theta upper bound
args.lbx(4:n_states:n_states*(N+1),1) = xmin(4); %state velocity lower bound
args.ubx(4:n_states:n_states*(N+1),1) = xmax(4); %state velocity upper bound


args.lbx(n_states*(N+1)+1:n_controls:n_states*(N+1)+n_controls*N,1) = umin(1); %v lower bound
args.ubx(n_states*(N+1)+1:n_controls:n_states*(N+1)+n_controls*N,1) = umax(1); %v upper bound
args.lbx(n_states*(N+1)+2:n_controls:n_states*(N+1)+n_controls*N,1) = umin(2); %w lower bound
args.ubx(n_states*(N+1)+2:n_controls:n_states*(N+1)+n_controls*N,1) = umax(2); %w upper bound




%% Simulate MPC controller with AUV dynamics
t0 = 0;
xlog(:,1) = x0; % xx contains the history of states
t(1) = t0;
u0 = zeros(N,n_controls);
X0 = repmat(x0,1,N+1)';


% Start MPC
mpciter = 0;
xx1 = [];
u_cl=[];


w_bar = waitbar(0,'1','Name','Simulating MPC-CDF...',...
    'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');

while(norm((x0-xf),2) > 1e-2 && mpciter < time_total / dt)
    max_iter = time_total/dt;
    waitbar(mpciter/max_iter,w_bar,sprintf(string(mpciter)+'/'+string(max_iter)))
    
    args.p   = [x0;xf]; % set the values of the parameters vector

    % initial value of the optimization variables
    args.x0  = [reshape(X0',n_states*(N+1),1);reshape(u0',n_controls*N,1)];
    sol = solver('x0', args.x0, 'lbx', args.lbx, 'ubx', args.ubx,...
        'lbg', args.lbg, 'ubg', args.ubg,'p',args.p);
    u = reshape(full(sol.x(n_states*(N+1)+1:end))',n_controls,N)'; % get controls only from the solution
    xx1(:,1:n_states,mpciter+1)= reshape(full(sol.x(1:n_states*(N+1)))',n_states,N+1)'; % get solution TRAJECTORY
    u_cl= [u_cl ; u(1,:)];
    t(mpciter+1) = t0;

    % Apply the control and shift the solution
    if(mismatch)
        [t0, x0, u0] = shift(dt, t0, x0, u,F_mismatch);
    else
        [t0, x0, u0] = shift(dt, t0, x0, u,F);
    end

    xlog(:,mpciter+1) = x0;
    X0 = reshape(full(sol.x(1:n_states*(N+1)))',n_states,N+1)'; % get solution TRAJECTORY


    % Shift trajectory to initialize the next step
    X0 = [X0(2:end,:);X0(end,:)];
    mpciter = mpciter + 1;
end

F = findall(0,'type','figure','tag','TMWWaitbar');
delete(F);

%% ---------------- plot 2D trajectory ----------------------  

figure(1)

% For legend as rectangular object can't be defined as a legend
    dummy_marker = plot(NaN,NaN, 'o','MarkerSize', 10, 'MarkerEdgeColor',...
            'black', 'MarkerFaceColor',obsColor, 'LineWidth', 1.5); 

% plot x-y-z trajecotry
traj = plot(xlog(1,:), xlog(2,:),'LineWidth', 2,'Color',red);
xlabel('x(m)','interpreter','latex','FontSize',20);
ylabel('y(m)','interpreter','latex','FontSize',20);
hold on

% plot start and target 
% plot(x_ini(1), x_ini(2), 'o', 'MarkerSize',10, 'MarkerFaceColor','black','MarkerEdgeColor','black'); hold on;
% plot(xf(1), xf(2), 'o', 'MarkerSize',10, 'MarkerFaceColor',green,'MarkerEdgeColor',green); hold on;

% plot obstacles
xc = obs1(1); yc = obs1(2); Rc = obs1(3);
angles = (0:100-1)*(2*pi/100);
points = [xc;yc] + [Rc*cos(angles);Rc*sin(angles)];
P = polyshape(points(1,:), points(2,:));
plot(P, 'FaceColor', obsColor, 'LineWidth', 2, 'FaceAlpha', 1.0); hold on;

%setup plots
axes1 = gca;
box(axes1,'on');
axis(axes1,'equal');

% set other axis properties
set(axes1,'FontSize',15,'LineWidth',2);
if(cbf_constraint)
    lgd = legend(traj,'CBF with $\gamma$ = '+string(gamma));
else
    lgd = legend(traj,'distance');
end

lgd.Interpreter = 'latex';
lgd.FontSize = 15;
grid on;
xlim([0,10])
ylim([yc-5,yc+5])
hold(axes1,'off');
xlabel('Position, $x$ (m)','interpreter','latex', 'FontSize', 20);
ylabel('Position, $y$ (m)','interpreter','latex', 'FontSize', 20);