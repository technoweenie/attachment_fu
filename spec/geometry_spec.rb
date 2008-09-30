require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'attachment_fu/geometry'

describe AttachmentFu::Geometry do
  it "resizes dimensions" do
    assert_geometry 50, 64,
      "50x50"   => [39, 50],
      "60x60"   => [47, 60],
      "100x100" => [78, 100]
  end
  
  it "resizes with only width dimension" do
    assert_geometry 50, 64,
      "x50"  => [39, 50],
      "x60"  => [47, 60],
      "x100" => [78, 100]
  end
  
  it "resizes with only height dimension" do
    assert_geometry 50, 64,
      "50"  => [50, 64],
      "60"  => [60, 77],
      "100" => [100, 128]
  end
  
  it "resizes with percentage" do
    assert_geometry 50, 64,
      "50x50%"   => [25, 32],
      "60x60%"   => [30, 38],
      "120x112%" => [60, 72]
  end
  
  it "resizes with percentage and no height" do
    assert_geometry 50, 64,
      "x50%"  => [50, 32],
      "x60%"  => [50, 38],
      "x112%" => [50, 72]
  end
  
  it "resizes with percentage and no width" do
    assert_geometry 50, 64,
      "50%"  => [25, 32],
      "60%"  => [30, 38],
      "120%" => [60, 77]
  end
  
  it "resizes with less (<)" do
    assert_geometry 50, 64,
      "50x50<"   => [50, 64],
      "60x60<"   => [50, 64],
      "100x100<" => [78, 100],
      "100x112<" => [88, 112],
      "40x70<"   => [50, 64]
  end
  
  it "resizes with less (<) and no height" do
    assert_geometry 50, 64,
      "x50<"  => [50, 64],
      "x60<"  => [50, 64],
      "x100<" => [78, 100]
  end
  
  it "resizes with less (<) and no width" do
    assert_geometry 50, 64,
      "50<"  => [50, 64],
      "60<"  => [60, 77],
      "100<" => [100, 128]
  end

  it "resizes with greater (>)" do
    assert_geometry 50, 64,
      "50x50>"   => [39, 50],
      "60x60>"   => [47, 60],
      "100x100>" => [50, 64],
      "100x112>" => [50, 64],
      "40x70>"   => [40, 51]
  end
  
  it "resizes with greater (>) and no height" do
    assert_geometry 50, 64,
      "x40>"  => [31, 40],
      "x60>"  => [47, 60],
      "x100>" => [50, 64]
  end
  
  it "resizes with greater (>) and no width" do
    assert_geometry 50, 64,
      "40>"  => [40, 51],
      "60>"  => [50, 64],
      "100>" => [50, 64]
  end

  protected
    def assert_geometry(width, height, values)
      values.each do |geo, result|
        # run twice to verify the Geometry string isn't modified after a run
        geo = AttachmentFu::Geometry.from_s(geo)
        2.times { result.should == ([width, height] / geo) }
      end
    end
end