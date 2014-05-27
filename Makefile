all: json

json: pdfs
	bundle exec ruby lib/parser.rb

pdfs: filelist
	wget -w 0 -N -i data/filelist.txt -P data

filelist: datadir
	bundle exec ruby lib/scraper.rb > data/filelist.txt

datadir:
	mkdir -p data

clean:
	rm -r data
