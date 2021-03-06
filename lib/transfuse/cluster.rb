module Transfuse

  require 'bio'
  require 'fixwhich'

  class Cluster

    def initialize threads, verbose
      @cdhit = Which::which('cd-hit-est').first
      raise "cd-hit-est was not in the PATH - please install it" unless @cdhit
      @vsearch = Which::which('vsearch').first
      raise "vsearch was not in the PATH - please install it" unless @vsearch
      @id = "1.00"
      @threads = threads
      @verbose = verbose
    end

    def run fasta
      use_cd_hit = false
      if use_cd_hit
        output = cd_hit fasta
        return parse_output output
      else
        output = vsearch fasta
        return parse_vsearch_output output
      end
    end

    def cd_hit fasta
      puts "running cd-hit-est" if @verbose
      output = "#{File.basename(fasta, File.extname(fasta))}_cdhit.fa"
      cdhit_cmd = generate_cdhit_command fasta, output
      puts cdhit_cmd if @verbose
      cluster = Cmd.new cdhit_cmd
      cluster.run output
      return "#{output}.clstr"
    end

    def vsearch fasta
      puts "running vsearch" if @verbose
      cluster_output = "#{fasta}.clust"
      vsearch_cmd = generate_vsearch_command fasta, cluster_output
      cluster = Cmd.new vsearch_cmd
      cluster.run cluster_output
      return cluster_output
    end

    def generate_cdhit_command fasta, out
      #cd-hit-est -i all.fa  -o cd-hit-clusters.txt -c 0.99999 -T 24 -d 100
      cmd = "#{@cdhit}"
      cmd << " -i #{fasta}"
      cmd << " -o #{out}"
      cmd << " -c #{@id}" # similarity = number of identical bases /
                          #              length of shorter sequences
      cmd << " -T #{@threads}"
      cmd << " -n 10" # word length - maybe increase??
      cmd << " -d 100" # output name width
      cmd << " -g 1" # slower but more accurate mode
      cmd << " -M 8000" # increase memory
    end

    def generate_vsearch_command fasta, out
      vsearch = "#{@vsearch}"
      vsearch << " --cluster_fast #{fasta}"
      vsearch << " --id #{@id}"
      vsearch << " --iddef 0" # cd-hit definition of sequence id
      vsearch << " --qmask none" # no masking
      vsearch << " --strand both"
      vsearch << " --uc #{out}"
      vsearch << " --threads #{@threads}"
      return vsearch
    end

    def parse_output cluster_output
      puts "parsing cd-hit output #{cluster_output}" if @verbose
      cluster_id = 0
      clusters = {}
      File.open(cluster_output).each_line do |line|
        if line =~ />Cluster\ ([0-9]+)/
          cluster_id = $1.to_i
        elsif line =~ /[0-9]+\s+.+nt,\ >(.+)\.\.\.\sat\s([+\-])\/([0-9\.]+)\%/
          contig_name = $1
          strand = $2
          id = $3.to_f
          clusters[cluster_id] ||= []
          clusters[cluster_id] << { :name => contig_name, :strand => strand }
        elsif line =~ /[0-9]+\s+[0-9]+nt,\s>(.+)\.\.\.\s\*/
          contig_name = $1
          strand = "+"
          clusters[cluster_id] ||= []
          clusters[cluster_id] << { :name => contig_name, :strand => strand }
        end
      end
      return clusters
    end

    def parse_vsearch_output cluster_output
      clusters = {}
      File.open(cluster_output).each_line do |line|
        if line.start_with?("S") or line.start_with?("H")
          cols = line.chomp.split("\t")
          cluster = cols[1].to_i
          contig_name = cols[8]
          clusters[cluster] ||= []
          clusters[cluster] << contig_name
        end
      end
      return clusters
    end

  end

end
