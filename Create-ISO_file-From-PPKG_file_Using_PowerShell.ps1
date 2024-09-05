Cls
Set-ExecutionPolicy -ExecutionPolicy Bypass
<#  
   Synopsis    --> Generates a new .iso file  
   Description --> The Create-ImageFile cmdlet generates a new .iso file containing content from specified folders or files.  
   Example     -->   Create-ImageFile "C:\FolderA","C:\FolderB"  
  
   Find me @ 
   Youtube:-        https://www.youtube.com/@chandermanipandey8763
   Twitter:-        https://twitter.com/Mani_CMPandey
   LinkedIn:-       https://www.linkedin.com/in/chandermanipandey

#>
# ==============================================User Input Section=======================================================================

$inputFolder = "C:\Users\WDAGUtilityAccount\Downloads" # Enter the directory containing files to include in the ISO

# =======================================================================================================================================

# Function Definition
function Create-ImageFile  
{  
  
  
  [CmdletBinding(DefaultParameterSetName='InputSource')]
  Param( 
    [parameter(Position=1,Mandatory=$true,ValueFromPipeline=$true, ParameterSetName='InputSource')]
    $InputSource,  
    
    [parameter(Position=2)][string]$OutputPath = "$env:temp\$((Get-Date).ToString('yyyyMMdd-HHmmss.ffff')).iso",  
    
    [ValidateScript({Test-Path -LiteralPath $_ -PathType Leaf})]
    [string]$BootImage = $null, 
    
    [ValidateSet('CDR','CDRW','DVDRAM','DVDPLUSR','DVDPLUSRW','DVDPLUSR_DUALLAYER','DVDDASHR','DVDDASHRW','DVDDASHR_DUALLAYER','DISK','DVDPLUSRW_DUALLAYER','BDR','BDRE')]
    [string] $MediaType = 'DVDPLUSRW_DUALLAYER', 
    
    [string]$VolumeName = (Get-Date).ToString("yyyyMMdd-HHmmss.ffff"),  
    
    [switch]$Overwrite, 
    
    [parameter(ParameterSetName='Clipboard')]
    [switch]$UseClipboard 
  ) 
 
  Begin {  
    Write-Host "Starting the ISO creation process..." -ForegroundColor Cyan
    ($compilerParams = new-object System.CodeDom.Compiler.CompilerParameters).CompilerOptions = '/unsafe' 
    if (!('ImageFile' -as [type])) {  
      Add-Type -CompilerParameters $compilerParams -TypeDefinition @' 
public class ImageFile  
{ 
  public unsafe static void Generate(string OutputPath, object StreamSource, int BufferSize, int TotalBuffers)  
  {  
    int byteCount = 0;  
    byte[] buffer = new byte[BufferSize];  
    var bytePtr = (System.IntPtr)(&byteCount);  
    var outputFile = System.IO.File.OpenWrite(OutputPath);  
    var streamInput = StreamSource as System.Runtime.InteropServices.ComTypes.IStream;  
  
    if (outputFile != null) { 
      while (TotalBuffers-- > 0) {  
        streamInput.Read(buffer, BufferSize, bytePtr); 
        outputFile.Write(buffer, 0, byteCount);  
      }  
      outputFile.Flush(); 
      outputFile.Close();  
    } 
  } 
}  
'@  
      Write-Host "Loaded ImageFile class for ISO creation." -ForegroundColor Green
    } 
  
    if ($BootImage) { 
      if('BDR','BDRE' -contains $MediaType) { 
        Write-Warning "Bootable image might not be compatible with media type $MediaType" 
      } 
      ($streamInstance = New-Object -ComObject ADODB.Stream -Property @{Type=1}).Open()  
      $streamInstance.LoadFromFile((Get-Item -LiteralPath $BootImage).Fullname) 
      ($bootOptions = New-Object -ComObject IMAPI2FS.BootOptions).AssignBootImage($streamInstance)
      Write-Host "Boot image loaded from $BootImage." -ForegroundColor Green
    } 
 
    $MediaTypesList = @('CDROM', 'CDR', 'CDRW', 'DISK', 'DVDROM', 'DVDRAM', 'DVDPLUSR', 'DVDPLUSRW', 'DVDPLUSR_DUALLAYER', 'DVDDASHR', 'DVDDASHRW', 'DVDDASHR_DUALLAYER', 'UNKNOWN', 'BDROM', 'BDR', 'BDRE', 'HDDVDROM', 'HDDVDR', 'HDDVDRAM') 
 # Valid media types
    
    Write-Verbose -Message "Selected media type is $MediaType with value $($MediaTypesList.IndexOf($MediaType))" 
    ($fileSystemImage = New-Object -com IMAPI2FS.MsftFileSystemImage -Property @{VolumeName=$VolumeName}).ChooseImageDefaultsForMediaType($MediaTypesList.IndexOf($MediaType)) 
  
    if (!($OutputFile = New-Item -Path $OutputPath -ItemType File -Force:$Overwrite -ErrorAction SilentlyContinue)) { 
        Write-Error -Message "Cannot create file $OutputPath. Use -Overwrite parameter to replace if the target file already exists." 
        break 
    } else {
        Write-Host "Output file will be created at $OutputPath." -ForegroundColor Green
    }
  }  
 
  Process { 
    if($UseClipboard) { 
      if($PSVersionTable.PSVersion.Major -lt 5) { 
        Write-Error -Message 'The -UseClipboard parameter requires PowerShell version 5 or higher' 
        break 
      } 
      $InputSource = Get-Clipboard -Format FileDropList 
      Write-Host "Files and folders obtained from clipboard." -ForegroundColor Green
    } 
 
    foreach($element in $InputSource) { 
      if($element -isnot [System.IO.FileInfo] -and $element -isnot [System.IO.DirectoryInfo]) { 
        $element = Get-Item -LiteralPath $element 
      } 
 
      if($element) { 
        Write-Host "Adding item to the ISO: $($element.FullName)" -ForegroundColor Yellow
        try { 
            $fileSystemImage.Root.AddTree($element.FullName, $true) 
        } catch { 
            Write-Error -Message ($_.Exception.Message.Trim() + ' Please try a different media type.') 
        } 
      } 
    } 
  } 
 
  End {  
    if ($bootOptions) { 
        $fileSystemImage.BootImageOptions=$bootOptions 
        Write-Host "Boot image options have been applied." -ForegroundColor Green
    }  
    $ImageResult = $fileSystemImage.CreateResultImage()  
    [ImageFile]::Generate($OutputFile.FullName,$ImageResult.ImageStream,$ImageResult.BlockSize,$ImageResult.TotalBlocks) 
    Write-Host "ISO image has been successfully created at: $($OutputFile.FullName)" -ForegroundColor Green
    $OutputFile | Out-Null
  } 
} 

# Find the .ppkg file in the input folder
$ppkgFile = Get-ChildItem -Path $inputFolder -Filter "*.ppkg" -File -Recurse | Select-Object -First 1

if (-not $ppkgFile) {
    Write-Error "No .ppkg file found in the specified directory."
    exit
}

# Generate output ISO file path based on the .ppkg file name
$outputIsoFile = Join-Path -Path $ppkgFile.DirectoryName -ChildPath ($ppkgFile.BaseName + ".iso")
Write-Host "The output ISO file will be created at: $outputIsoFile" -ForegroundColor Cyan

# Execution
Write-Host "Starting ISO creation process from $inputFolder to $outputIsoFile..." -ForegroundColor Cyan
Get-ChildItem -Path $inputFolder | Create-ImageFile -OutputPath $outputIsoFile -Overwrite
Write-Host "Process completed." -ForegroundColor Green