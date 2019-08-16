build:
	docker build -t metaboshiny .

server:
	docker run -p 8080:8080 -v $(PWD):/root/MetaboShiny/:cached --rm -it metaboshiny Rscript startShiny.R

