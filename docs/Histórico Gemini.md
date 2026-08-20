## Premissas de um bom jogo ##
1. Mecânica Core Instantânea ("Fácil de Jogar, Difícil de Dominar")  
- Controle de Um Único Dedo (One-Touch): O jogador não pode ter dificuldades com controles. Ele apenas desliza o dedo para mover a multidão ou direcionar os tiros.  
- Feedback Visual e Sonoro Intenso (Juice): Cada inimigo derrotado deve gerar um efeito gratificante (som de estouro, moedas voando, vibração leve no aparelho). A sensação de "limpar" uma multidão gigante dispara dopamina rápida.  
- Progressão Numérica Visível: Mostrar contadores na tela (ex: sua multidão de 10 pessoas contra 100 inimigos) cria urgência e clareza imediata sobre vitória ou derrota.  
2. O Loop Infinito (O Efeito Candy Crush)  
- Sessões Curtas e Rápidas: Partidas de 30 segundos a 2 minutos. O jogador precisa sentir que "dá tempo de jogar mais uma" no ônibus ou numa pausa rápida.  
- Dificuldade Dinâmica e Escalável: Alternar fases fáceis (onde o jogador se sente muito poderoso) com fases desafiadoras (que exigem upgrades).  
- Sensação de Recompensa Contínua: Vitória deve render moedas para melhorar a velocidade de tiro, o tamanho inicial do exército ou o dano da arma, gerando um ciclo viciante de jogar $\rightarrow$ ganhar moedas $\rightarrow$ evoluir $\rightarrow$ jogar de novo.  
3. Integração Online e Modo Criador (Cenários)  
- Editor de Mapas Drag-and-Drop: Uma ferramenta simples no próprio celular para posicionar obstáculos, multiplicadores de tropas e hordas de inimigos.  
- Comunidade e Desafios Diários: Permitir que jogadores publiquem seus mapas e desafiem outros a vencerem seus cenários com o menor tempo ou menor número de perdas.  
- Rankings de Criadores: Pontuar os mapas criados pela comunidade com base em avaliações (estrelas ou curtidas), recompensando os criadores com moedas do jogo.  
4. Elementos Estratégicos e de Multiplicação  
- Portais de Decisão Rápida: Colocar portais de operação matemática no caminho ($+10$, $\times2$, $-5$, $\div2$). O jogador precisa escolher o melhor caminho em milissegundos enquanto avança e atira.  
- Inimigos Horda (Horde Defense): A sensação visual de ter uma onda gigante de bonecos se aproximando cria a urgência de atirar rápido e aumentar o próprio exército antes da colisão.


# GDD - Jogo Shooter Casual de Escritório

## Concept Core
- Estilo: Top-down Crowd Shooter (Hyper-Casual)
- Tema: Humor corporativo. O jogador atira nos funcionários em um escritório para transformá-los em moedas coletáveis.
- Mecânica de Clones: Cada moeda coletada gera 1 clone do jogador.
- Dificuldade Dinâmica: A cada novo clone gerado, a vida/força dos inimigos restantes aumenta em 0,5x.

## Inimigos & Hierarquia
- Estagiário: Vida baixa, 1 moeda (1 clone).
- Analista: Vida média, ataque à distância (clipes de papel).
- Diretor/Boss: Vida alta, localizado na Sala de Reunião, concede muitas moedas.
- Comportamento: Ficam nas baias em "modo espera" e entram em alerta quando o jogador se aproxima.

## Editor de Cenários (Mapas Customizados)
- Formato: Módulos/Salas pré-definidas (Cafeteria, Baias, Diretoria).
- Exportação: Gerado em formato JSON leve enviado para a API Flask backend.

## Multiplayer / Online
- Coop: Jogadores se unem para limpar o escritório.
- Versus (PvP): Corrida para ver quem converte mais funcionários primeiro.