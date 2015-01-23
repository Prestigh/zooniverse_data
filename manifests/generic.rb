#!/usr/bin/env ruby
require_relative 'manifest'

require 'aws-sdk'
require 'json'
require 'csv'
require 'active_support'
require 'pry'

class GenericManifest
  include Manifest

  InvalidMetadata = Class.new(StandardError)
  DupImageName = Class.new(StandardError)

  CSV_FILELIST_NAME = "filelist.csv"
  IMAGE_FILE_REGEX = "\.(jp(e)?g|png)$"
  SUBJECT_META_REGEX = "((?<group_name>[a-zA-Z0-9_-]+)/)(?<key>.+)#{IMAGE_FILE_REGEX}"
  PROJECT_DATA_PATH = "project_data"

  def initialize
    if ENV['AWS_ACCESS_KEY_ID'] != nil
      AWS.config({
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_KEY']
      })
    end

    if ARGV[1]
      @subject_meta_regex = ARGV[1]
    else
      @subject_meta_regex = SUBJECT_META_REGEX
    end

    @csv_image_metadata = Hash.new { |h,k| h[k] = { :location => [], :metadata => {} } }
    @group_metadata = Hash.new { |h,k| h[k] = { :metadata => {} } }
    @sample = false
    @sample_size = 200
    @header_row = []
  end

  def prepare
    load_csv_image_metadata

    @group_metadata.each_pair do |group_key, group_hash|
      group_hash[:name] = group_key
      group group_hash
    end

    @csv_image_metadata.each_pair do |subject_key, subject_hash|
      if subject_hash[:location].length == 1
        subject_hash[:location] = subject_hash[:location][0]
      end
      subject subject_hash
    end
  end

  def project_name
    ARGV[0]
  end

  private

    def load_csv_image_metadata
      filelist = zooniverse_data_bucket.objects["#{PROJECT_DATA_PATH}/#{project_name}/#{CSV_FILELIST_NAME}"]
      csv_file_data = CSV.parse(filelist.read)
      @header_row = csv_file_data.shift
      read_csv_file_rows(csv_file_data)
    end

    def s3
      @s3 ||= AWS::S3.new
    end

    def zooniverse_data_bucket
      @zoo_data_bucket ||= s3.buckets['zooniverse-data']
    end

    def read_csv_file_rows(csv_file_data)
      csv_file_data.each do |row|
        row.unshift(nil) if row.length != @header_row.length && row.first.match(/#{IMAGE_FILE_REGEX}/i)
        row = row.map! { |val| val && (val.empty? || val.match(/na/i)) ? nil : val }

        subject_match = row[0].match(/#{@subject_meta_regex}/)
        @csv_image_metadata[subject_match[:key]][:location].push(url_of(row[0]))

        if subject_match[:group_name]
          @group_metadata[subject_match[:group_name]] = { :metadata => {} }
          @csv_image_metadata[subject_match[:key]][:group_name] = subject_match[:group_name]
        end

        # Skip col 0
        current_col = 1
        row.shift
        coords = {}
        row.each do |col|
          if @header_row[current_col] == 'latitude' or @header_row[current_col] == 'longitude'
            coords[@header_row[current_col]] = col
          else
            @csv_image_metadata[subject_match[:key]][:metadata][@header_row[current_col]] = col
          end
          current_col += 1
        end

        if coords['latitude'] and coords['longitude']
           @csv_image_metadata[subject_match[:key]][:coords] = [ coords['longitude'], coords['latitude'] ]
        end
      end
    end
end

GenericManifest.create
