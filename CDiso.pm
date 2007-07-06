package CDiso;

use Cwd;

# Some package level globals
$VERSION="1.0.0.2";

sub new
{
    my ($self, $root)=@_;

    $self={ 
        _root=>undef,
        _files=>undef,
        _size=>0,
        _mkisofs_path=> 'mkisofs',
        _volume_label=> time(),         #default to time
          };

    bless $self, 'CDiso';

    if(defined($root) && -d $root)
    {
        $self->{_root} = $root;
    }

    return $self;
}

sub version
{
    my ($self) = @_;
    return $VERSION;
}

sub size
{
    my ($self) = @_;
    return $self->{_size};
}


sub mkisofsPath 
{
    my ($self, $path) = @_;
    $self->{_mkisofs_path} = $path if(defined($path) && -e $path);
    return $self->{_mkisofs_path};
}

sub volumeLabel
{
    my ($self, $label) = @_;
    $self->{_volume_label} = $label if defined($label);
    return $self->{_volume_label};
}

sub root
{
    my ($self, $root) = @_;
    $self->{_root} = $root if(defined($root) && -d $root);
    return $self->{_root};
}

sub addFiles
{
    my ($self, @files) = @_;

    my @fileinfo;

    
    if(!defined($self->{_root}))
    {
        error("root directory not set");
    }

    foreach $file(@files)
    {
        if(-e $file)
        {
            if(!($file=~m/^$self->{_root}/))
            {
                warn("file $file is not in a sub-directory of root dir $self->{_root}");
                warn("NOT adding file $file");
            }
            else
            {
                if(!defined($self->{_files}{$file}))
                {
                    $self->{_files}{$file}=1;
                    @fileinfo = stat($file);
                    $self->{_size} += $fileinfo[7]; # 7 = file size in bytes

                }
            }
        }
        else
        {
            warn("file does not exist: $file");
        }
    }
}

sub printFiles
{
    my ($self) = @_;

    foreach $file(keys %{$self->{_files}})
    {
        print "$file\n";
    }
}

sub makeISO
{
    my($self, $imageName) = @_;

    if(!defined($imageName))
    {
        error("makeISO called, but no image name provided.\n");
    }

    my $tmpdir = $self->getTempDir();
    my $excludeFile =  $tmpdir. "/excludeList" . time() . ".txt";

    open OUT, ">$excludeFile" or error("Unable to open exclude file $excludeFile");

    my $cwd = cwd(); #save this off

    chdir($self->{_root}) || error("Unable to cd to $self->{_root}");

    $self->scanDir($self->{_root});

    chdir($cwd); # restore cwd

    close OUT;

    my @cmd = ($self->{_mkisofs_path},
	   "-r",		# rock ridge
	   "-J",		# joliet
       "-joliet-long", 
	   "-o", $imageName,
	   "-V", $self->{_volume_label},
	   "-v",
	   "-exclude-list", $excludeFile);

    foreach $path(@paths_to_exclude)
    {
        push(@cmd, '-x');
        push(@cmd, $path);
    }

    push(@cmd, $self->{_root});
	   
    print STDERR ("+ @cmd\n");
    system (@cmd);

    unlink($excludeFile) if -e $excludeFile;
}

sub scanDir
{
    my ($self, $dir) = @_;

    my $cwd = cwd();

    chdir($dir) || error("Unable to cd to $dir");

    my @files = <*>;

    my @dirs;

    my $return_value = 0;

    foreach $file(@files)
    {
        if(-d $file) { push(@dirs, $file); }
        else
        {
            if(!defined($self->{_files}{"$dir/$file"}))
            {
                print OUT "$dir/$file\n";
            }
            else
            {
                $return_value = 1;
            }
        }
    }

    foreach $directory(@dirs)
    {
        $return_value |= $self->scanDir("$dir/$directory");
    }

    if($return_value == 0)
    {
        push(@paths_to_exclude, $dir);
    }

    return $return_value;
}

sub getTempDir
{
    my ($self) = @_;

    if(defined($ENV{'TEMP'}) && -d $ENV{'TEMP'}) { return $ENV{'TEMP'}; } 
    if(defined($ENV{'TMP'}) && -d $ENV{'TMP'}) { return $ENV{'TMP'}; } 
    if(defined($ENV{'TEMPDIR'}) && -d $ENV{'TEMPDIR'}) { return $ENV{'TEMPDIR'}; } 
    # as a last resort, try /tmp
    if(-d '/tmp') { return '/tmp'; } 

    error("Unable to determine a temporary directory.");
}

sub error
{
    my ($msg) = @_;
    print "ERROR: $msg\n";
    exit(1);
}

sub warn
{
    my ($msg) = @_;
    print "WARNING: $msg\n";
}

=head1 NAME

B<CDiso> - A package that wraps the mkisofs interface to simplify the process of making CD disk
images

=head1 SYNOPSIS
 use CDiso;

 my $iso = new CDiso('/tmp/test');

 $iso->mkisofsPath('/path/to/mkisofs');

 # files that you want to add
 $files[0]='/tmp/test/a.txt';
 $files[1]='/tmp/test/b.txt';
 $files[2]='/tmp/test/c.txt';
 $files[3]='/tmp/test/level1/level1_a.txt';

 # add the files
 $iso->addFiles(@files);

 #make the iso
 $iso->makeISO("/path/to/example.iso");

=head1 DESCRIPTION

This module provides a front end for the mkisofs program.

=head1 METHODS

=head2 addFiles()

	$iso->addFiles(@array_of_files_to_add);
	$iso->addFiles($individual_file_to_add);

    Adds the file(s) specified in the arguments to the function to the files that will be included
    when making the disk image

=head2 makeISO()

	$iso->makeISO('/tmp/output.iso');
    
    This is the method where all the magic happens. This method constructs a disk image by making a
    call to the mkisofs program. The files included on the disk image are only those files that were
    explicitly added via the addFiles method. All other files below the root directory are excluded.
    This method writes a temporary file to a temp directory, but removes that file once the .iso has
    been built. 

=head2 mkisofsPath()

	$iso->mkisofsPath('/path/to/mkisofs');

    Sets the path to the mkisofs executable.

=head2 new()
    
	$iso = new CDiso($root);

    Creates a new CDiso object. $root is an optional argument. $root is the path to the root of the
    files that you will be adding to the final .iso. If you don't set root via this constructor, you
    can set it by calling the I<root> method.

=head2 printFiles()

	$iso->printFiles

    Prints a list of all the files that have been added to the CDiso object. This is mainly for
    debugging purposes.

=head2 root()

	$iso->root($root);

    Sets the root of the files that will be included in the .iso image. 

=head2 size()

	$iso->size();

    Returns the size in bytes of all files that have been added to the iso. 

=head2 version()

	$iso->version();

    Returns the version of the CDiso package.

=head2 volumeLabel()

	$iso->volumeLabel($label);
    
    Sets the Volume label for the disk image to $label. If you do not set the volume label, it
    defaults to the system time (# of seconds since the epoch).

=head1 AUTHOR

Jason Hancock, C<< <jsnby at hotmail dot com> >>

=head1 BUGS

Please report any bugs or feature requests to C<jsnby AT hotmail DOT com>.

=head1 TODO

There are a few things I would like to add to this package in the future. One would be to check
the sizes of each file that is added to the disk image to make sure we don't exceed the 650MB or
700MB limits.

If you want something added, email me a request at (jsnby AT hotmail DOT com).

=head1 COPYRIGHT & LICENSE

Copyright (C) 2007 Jason Hancock (jsnby AT hotmail DOT com)
http://jsnby.is-a-geek.com

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

=cut

1;
