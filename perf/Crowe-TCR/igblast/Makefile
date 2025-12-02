all: jobs submit clean

jobs:
	python3 make_jobs.py

submit:
	bash submit-jobs.sh

clean:
	rm -f job*.json
