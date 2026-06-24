NAME    = inception
COMPOSE = srcs/docker-compose.yml
DATA    = /home/akoca/data
DB_DIR  = mariadb
WP_DIR  = wordpress

all: $(NAME)

$(NAME):
	mkdir -p $(DATA)/$(DB_DIR)
	mkdir -p $(DATA)/$(WP_DIR)
	docker compose -f $(COMPOSE) up --build -d

down:
	docker compose -f $(COMPOSE) down

clean: down
	docker compose -f $(COMPOSE) down --rmi all

fclean: clean
	sudo rm -rf $(DATA)/$(DB_DIR) $(DATA)/$(WP_DIR)

re: fclean all

.PHONY: all down clean fclean re
